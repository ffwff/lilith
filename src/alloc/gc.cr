require "./alloc.cr"

abstract class Gc; end

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
private GC_NODE_MAGIC_BLACK = 0x45564104
private GC_NODE_MAGIC_BLACK_ATOMIC = 0x45564104

private lib Kernel

    struct GcNode
        next_node : GcNode*
        magic : UInt32
    end

end

# private def check_gc_node(node : GcNode*)
#     case node.value.magic
#     when GC_NODE_MAGIC | GC_NODE_MAGIC_ATOMIC | GC_NODE_MAGIC_GRAY | GC_NODE_MAGIC_GRAY_ATOMIC | GC_NODE_MAGIC_BLACK |
#         true
#     else
#         false
#     end
# end

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
    @@root_scanned = false

    struct TypeInfo
        def initialize(@offsets : UInt32, @size : UInt32); end
        def offsets; @offsets; end
        def size; @size; end
    end

    def init(@@data_start : UInt32, @@data_end : UInt32, @@stack_end : UInt32)
        @@type_info = BTree(UInt32, TypeInfo).new
        type_info = @@type_info.not_nil!
        offsets : UInt32 = 0
        {% for klass in Gc.all_subclasses %}
            offsets = 0
            # set zero offset if any of the field isn't 32-bit aligned
            zero_offset = false
            {% for ivar in klass.instance_vars %}
                {% if ivar.type < Gc %}
                    {{ puts klass.stringify + " = " + ivar.stringify }}
                    if offsetof({{ klass }}, @{{ ivar }}).unsafe_mod(4) == 0
                        field_offset = offsetof({{ klass }}, @{{ ivar }}).unsafe_div(4)
                        panic "struct pointer outside of 32-bit range!" if field_offset > 32
                       offsets |= 1.unsafe_shl(field_offset)
                    else
                        zero_offset = true
                    end
                {% end %}
            {% end %}
            if zero_offset
                type_info.insert({{ klass }}.crystal_instance_type_id.to_u32, TypeInfo.new(0, sizeof({{ klass }}).to_u32))
            else
                type_info.insert({{ klass }}.crystal_instance_type_id.to_u32, TypeInfo.new(offsets, sizeof({{ klass }}).to_u32))
            end
        {% end %}
        @@enabled = true
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

    # gc algorithm
    private def scan_region(start_addr, end_addr, move_list=true)
        # due to the way this rechains the linked list of white nodes
        # please set move_list=false when not scanning for root nodes
        word_size = 4 # 4*8 = 32bits
        debug "from: ", Pointer(Void).new(start_addr.to_u64), Pointer(Void).new(end_addr.to_u64),"\n"
        i = start_addr
        fix_white = false
        while i < end_addr - word_size + 1
            word = Pointer(UInt32).new(i.to_u64).value
            # subtract to get the pointer to the header
            word -= sizeof(Kernel::GcNode)
            if word >= KERNEL_ARENA.start_addr && word <= KERNEL_ARENA.placement_addr
                node = @@first_white_node
                prev = Pointer(Kernel::GcNode).null
                found = false
                while !node.null?
                    if node.address.to_u32 == word
                        # word looks like a valid gc header pointer!
                        # remove from current list
                        if move_list
                            if !prev.null?
                                prev.value.next_node = node.value.next_node
                            else
                                @@first_white_node = node.value.next_node
                            end
                        end
                        # add to gray list
                        case node.value.magic
                        when GC_NODE_MAGIC
                            node.value.magic = GC_NODE_MAGIC_GRAY
                            push(@@first_gray_node, node) if move_list
                            fix_white = true
                        when GC_NODE_MAGIC_ATOMIC
                            node.value.magic = GC_NODE_MAGIC_GRAY_ATOMIC
                            push(@@first_gray_node, node) if move_list
                            fix_white = true
                        when GC_NODE_MAGIC_BLACK | GC_NODE_MAGIC_BLACK_ATOMIC
                            panic "invariance broken"
                        else
                            # this node is gray
                        end
                        found = true
                        break
                    end
                    # next it
                    prev = node
                    node = node.value.next_node
                end
                debug Pointer(Void).new(word.to_u64), found ? " (found)" : "", "\n"
            end
            i += 1
        end
        fix_white
    end

    def cycle
        if @@bytes_allocated == 0
            # nothing's allocated
            return
        end

        # marking phase
        if !@@root_scanned
            # we don't have any gray/black nodes at the beginning of a cycle
            # conservatively scan the stack for pointers
            scan_region @@data_start.not_nil!, @@data_end.not_nil!
            stack_start = 0
            asm("mov %esp, $0;" : "=r"(stack_start) :: "volatile")
            scan_region stack_start, @@stack_end.not_nil!
            @@root_scanned = true
        elsif !@@first_gray_node.null?
            # second stage of marking phase: precisely marking gray nodes
            type_info = @@type_info.not_nil!
            #new_first_gray_node = Pointer(Kernel::GcNode).null

            fix_white = false
            node = @@first_gray_node
            while !node.null?
                debug "node: ", node, "\n"
                if node.value.magic == GC_NODE_MAGIC_GRAY_ATOMIC
                    # skip atomic nodes
                    node.value.magic = GC_NODE_MAGIC_BLACK_ATOMIC
                    node = node.value.next_node
                    next
                end
                panic "invariance broken" if node.value.magic == GC_NODE_MAGIC || node.value.magic == GC_NODE_MAGIC_ATOMIC

                node.value.magic = GC_NODE_MAGIC_BLACK

                buffer_addr = node.address.to_u64 + sizeof(Kernel::GcNode) + TYPE_ID_SIZE
                # get its typeid
                type_id = Pointer(UInt32).new(node.address.to_u64 + sizeof(Kernel::GcNode)).value
                debug "type: ", type_id, "\n"
                # lookup its offsets
                info = type_info.search(type_id).not_nil!
                offsets, size = info.offsets, info.size
                if offsets == 0
                    # since there is no offset found for this type, conservatively scan the region
                    buffer_end = buffer_addr + size
                    if scan_region buffer_addr, buffer_end, false
                        fix_white = true
                    end
                else
                    # precisely scan the struct based on the offsets
                    pos = 0
                    while offsets != 0
                        if offsets & 1
                            # lookup the buffer address in its offset
                            addr = Pointer(UInt32).new(buffer_addr + pos.to_u64 * 4).value
                            debug "pointer@", pos, " ", Pointer(Void).new(buffer_addr + pos.to_u64 * 4), " = ", Pointer(Void).new(addr.to_u64), "\n"

                            # rechain the offset on to the first gray node
                            header = Pointer(Kernel::GcNode).new(addr.to_u64 - sizeof(Kernel::GcNode))
                            case header.value.magic
                            when GC_NODE_MAGIC
                                header.value.magic = GC_NODE_MAGIC_GRAY
                                fix_white = true
                            when GC_NODE_MAGIC_ATOMIC
                                header.value.magic = GC_NODE_MAGIC_GRAY_ATOMIC
                                fix_white = true
                            else
                                # this node is either gray or black
                            end
                        end
                        pos += 1
                        offsets = offsets.unsafe_shr 1
                    end
                end
                node = node.value.next_node
            end

            # nodes in @@first_gray_node are now black
            node = @@first_gray_node
            while !node.null?
                next_node = node.value.next_node
                push(@@first_black_node, node)
                node = next_node
            end
            @@first_gray_node = Pointer(Kernel::GcNode).null
            ## some nodes in @@first_white_node are now gray
            if fix_white
                node = @@first_white_node
                new_first_white_node = Pointer(Kernel::GcNode).null
                while !node.null?
                    next_node = node.value.next_node
                    if node.value.magic == GC_NODE_MAGIC || node.value.magic == GC_NODE_MAGIC_ATOMIC
                        push(new_first_white_node, node)
                        node = next_node
                    elsif node.value.magic == GC_NODE_MAGIC_GRAY || node.value.magic == GC_NODE_MAGIC_GRAY_ATOMIC
                        push(@@first_gray_node, node)
                        node = next_node
                    else
                        panic "invariance broken"
                    end
                    node = next_node
                end
                @@first_white_node = new_first_white_node
            end

            if @@first_gray_node.null?
                # sweeping phase
                debug "sweeping phase\n"
                node = @@first_white_node
                while !node.null?
                    debug "free ", node, "\n"
                    next_node = node.value.next_node
                    KERNEL_ARENA.free node.address.to_u32
                    node = next_node
                end
                @@first_white_node = @@first_black_node
                node = @@first_white_node
                while !node.null?
                    case node.value.magic
                    when GC_NODE_MAGIC_BLACK
                        node.value.magic = GC_NODE_MAGIC
                    when GC_NODE_MAGIC_BLACK_ATOMIC
                        node.value.magic = GC_NODE_MAGIC_ATOMIC
                    else
                        panic "invariance broken"
                    end
                    node = node.value.next_node
                end
                @@first_black_node = Pointer(Kernel::GcNode).null
                @@root_scanned = false
                # begins a new cycle
            end
        end
    end

    def malloc(size : UInt32, atomic = false)
        if @@enabled
            cycle
        end
        size += sizeof(Kernel::GcNode)
        header = Pointer(Kernel::GcNode).new(KERNEL_ARENA.malloc(size).to_u64)
        header.value.magic = atomic ? GC_NODE_MAGIC_GRAY : GC_NODE_MAGIC_GRAY_ATOMIC
        # append node to linked list
        if @@enabled
            push(@@first_gray_node, header)
            @@bytes_allocated += size
        end
        # return
        ptr = Pointer(Void).new(header.address.to_u64 + sizeof(Kernel::GcNode))
        ptr
    end

    # printing
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

    private def debug(*args)
        #VGA.puts "GC: ", *args
    end

end