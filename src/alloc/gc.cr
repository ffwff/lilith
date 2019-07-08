require "./alloc.cr"

class Gc; end

fun __crystal_malloc64(size : UInt64) : Void*
    LibGc.malloc size.to_u32
end

fun __crystal_malloc_atomic64(size : UInt64) : Void*
    LibGc.malloc size.to_u32, true
end

# white nodes
private GC_NODE_MAGIC = 0x45564100
private GC_NODE_MAGIC_ATOMIC = 0x45564101
# gray nodes
private GC_NODE_MAGIC_GRAY = 0x45564102
private GC_NODE_MAGIC_GRAY_ATOMIC = 0x45564103
# black
private GC_NODE_BLACK = 0x45564104

private lib Kernel

    struct GcNode
        next_node : GcNode*
        magic : UInt32
    end

end

private def check_gc_node(node : GcNode*)
    case node.value.magic
    when GC_NODE_MAGIC | GC_NODE_MAGIC_ATOMIC | GC_NODE_MAGIC_GRAY | GC_NODE_MAGIC_GRAY_ATOMIC | GC_NODE_BLACK
        true
    else
        false
    end
end

module LibGc
    extend self

    INITIAL_THRESHOLD = 128
    USED_SPACE_RATIO = 0.7
    TYPE_ID_SIZE = sizeof(UInt32)
    @@bytes_allocated = 0
    @@threshold = INITIAL_THRESHOLD
    @@first_white_node = Pointer(Kernel::GcNode).null
    @@first_gray_node  = Pointer(Kernel::GcNode).null
    @@first_black_node = Pointer(Kernel::GcNode).null
    @@enabled = false

    def init(@@data_start : UInt32, @@data_end : UInt32, @@stack_end : UInt32)
        @@type_info = BTree(UInt32, UInt32).new
        type_info = @@type_info.not_nil!
        offsets : UInt32 = 0
        {% for klass in Gc.all_subclasses %}
            offsets = 0
            {% for ivar in klass.instance_vars %}
                {% if ivar.type < Gc %}
                    {{ puts klass.stringify + " = " + ivar.stringify }}
                    field_offset = offsetof({{ klass }}, @{{ ivar }}).unsafe_div(4)
                    panic "struct pointer outside of 32-bit range!" if field_offset > 32
                    # Serial.puts "offset @{{ ivar }}: ", field_offset, "\n"
                    offsets |= 1.unsafe_shl(field_offset)
                {% end %}
            {% end %}
            type_info.insert({{ klass }}.crystal_instance_type_id.to_u32, offsets)
        {% end %}
        # Serial.puts type_info, "\n"
        @@enabled = true
    end

    private def scan_region(start_addr, end_addr)
        word_size = 4 # 4*8 = 32bits
        Serial.puts "from: ", Pointer(Void).new(start_addr.to_u64), Pointer(Void).new(end_addr.to_u64),"\n"
        i = start_addr
        while i < end_addr - word_size + 1
            word = Pointer(UInt32).new(i.to_u64).value
            # subtract to get the pointer to the header
            word -= sizeof(Kernel::GcNode)
            if word >= KERNEL_ARENA.start_addr && word <= KERNEL_ARENA.placement_addr
                node = @@first_white_node
                prev = Pointer(Kernel::GcNode).null
                while !node.null?
                    if node.address.to_u32 == word
                        # word looks like a valid gc header pointer!
                    end
                    # next it
                    prev = node
                    node = node.value.next_node
                end
                word.to_s Serial, 16
                Serial.puts "\n"
            end
            i += 1
        end
    end

    macro push(list, node)
        if {{ list }}.null?
            # first node
            {{ node }}.value.next_node = Pointer(Kernel::GcNode).null
            {{ list }} = {{ node }}
        else
            # middle node
            {{ node }}.value.next_node = {{ list }}
            {{ list }} = {{ node }}
        end
    end

    macro push_black(node)
        {{ node }}.value.magic = GC_NODE_BLACK
        push(@@first_black_node, node)
    end

    # gc algorithm
    def cycle
        # marking phase
        if @@bytes_allocated == 0
            # nothing's allocated
            return
        elsif @@first_gray_node.null? && @@first_black_node.null?
            # we don't have any gray/black nodes at the beginning of a cycle
            # conservatively scan the stack for pointers
            # scan_region @@data_start.not_nil!, @@data_end.not_nil!
            # stack_start = 0
            # asm("mov %esp, $0;" : "=r"(stack_start) :: "volatile")
            # scan_region stack_start, @@stack_end.not_nil!
        elsif !@@first_gray_node.null?
            # second stage of marking phase: precisely marking gray nodes
            type_info = @@type_info.not_nil!
            new_first_gray_node = Pointer(Kernel::GcNode).null

            node = @@first_gray_node
            while !node.null?
                Serial.puts "node: ", node, "\n"
                if node.value.magic == GC_NODE_MAGIC_GRAY_ATOMIC
                    # skip atomic nodes
                    next_node = node.value.next_node
                    #push_black(node)
                    node = next_node
                    next
                end
                panic "gc invariance broken!" if node.value.magic == GC_NODE_MAGIC || node.value.magic == GC_NODE_MAGIC_ATOMIC

                buffer_addr = node.address.to_u64 + sizeof(Kernel::GcNode) + TYPE_ID_SIZE
                # get its typeid
                type_id = Pointer(UInt32).new(node.address.to_u64 + sizeof(Kernel::GcNode)).value
                Serial.puts "type: ", type_id, "\n"
                # lookup its offsets
                offsets = type_info.search(type_id).not_nil!
                pos = 0
                while offsets != 0
                    if offsets & 1
                        # lookup the buffer address in its offset
                        addr = Pointer(UInt32).new(buffer_addr + pos.to_u64 * 4).value
                        Serial.puts "pointer@", pos, " ", Pointer(Void).new(buffer_addr + pos.to_u64 * 4), " = 0x"
                        addr.to_s Serial, 16
                        Serial.puts "\n"

                        # rechain the offset on to the first gray node
                        header = Pointer(Kernel::GcNode).new(addr.to_u64 - sizeof(Kernel::GcNode))
                        case header.value.magic
                        when GC_NODE_MAGIC
                            header.value.magic = GC_NODE_MAGIC_GRAY
                            push(new_first_gray_node, header)
                        when GC_NODE_MAGIC_ATOMIC
                            header.value.magic = GC_NODE_MAGIC_GRAY_ATOMIC
                            push(new_first_gray_node, header)
                        else
                            # this node is either gray or black
                        end
                    end
                    pos += 1
                    offsets = offsets.unsafe_shr 1
                end

                # next it
                next_node = node.value.next_node
                push_black(node) if node.value.magic != GC_NODE_BLACK
                node.value.magic = GC_NODE_BLACK
                node = next_node
            end
            @@first_gray_node = new_first_gray_node
        else
            # sweeping phase
            Serial.puts "sweeping phase\n"
            node = @@first_white_node
            while !node.null?
                Serial.puts "free ", node, "\n"
                node.value.magic = 0
                KERNEL_ARENA.free node.address.to_u32
                node = node.value.next_node
            end
            @@first_white_node = @@first_black_node
            @@first_black_node = Pointer(Kernel::GcNode).null
        end
    end

    def malloc(size : UInt32, atomic = false)
        cycle if @@enabled
        size += sizeof(Kernel::GcNode)
        header = Pointer(Kernel::GcNode).new(KERNEL_ARENA.malloc(size).to_u64)
        header.value.magic = atomic ? GC_NODE_MAGIC_GRAY : GC_NODE_MAGIC_GRAY_ATOMIC
        # append node to linked list
        if @@enabled
            header.value.next_node = @@first_gray_node
            @@first_gray_node = header
            @@bytes_allocated += size
        end
        # return
        ptr = Pointer(Void).new(header.address.to_u64 + sizeof(Kernel::GcNode))
        Serial.puts self, "\n" if @@enabled
        Serial.puts "ret: ",header, ptr, "\n---\n" if @@enabled
        ptr
    end

    private def out_nodes(io, first_node)
        node = first_node
        while !node.null?
            io.puts node
            io.puts ", " if !node.value.next_node.null?
            node = node.value.next_node
        end
    end

    def to_s(io)
        io.puts "Gc {\n"
        io.puts "  white nodes: "
        out_nodes(io, @@first_white_node)
        io.puts "\n"
        io.puts "  gray nodes: "
        out_nodes(io, @@first_gray_node)
        io.puts "\n"
        io.puts "  black nodes: "
        out_nodes(io, @@first_black_node)
        io.puts "\n"
        io.puts "}"
    end

end