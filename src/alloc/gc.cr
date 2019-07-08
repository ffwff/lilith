require "./alloc.cr"

class Gc; end

fun __crystal_malloc64(size : UInt64) : Void*
    LibGc.malloc size.to_u32
end

fun __crystal_malloc_atomic64(size : UInt64) : Void*
    LibGc.malloc size.to_u32, true
end

private GC_NODE_MAGIC = 0x45564102
private GC_NODE_MAGIC_ATOMIC = 0x45564101

private lib Kernel

    struct GcNode
        next_node : GcNode*
        magic : UInt32
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

    def init
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

    # gc algorithm
    def cycle
        # marking phase
        if @@bytes_allocated == 0
            # nothing's allocated
            return
        elsif @@first_gray_node.null? && @@first_black_node.null?
            # we don't have any gray/black nodes at the beginning of a cycle
            # conservatively scan the stack for pointers
            stack_begin = 0
            asm("mov %esp, $0;" : "=r"(stack_begin) :: "volatile")
            stack_end = 0
            asm("mov %ebp, $0;" : "=r"(stack_end) :: "volatile")

            word_size = 4 # 4*8 = 32bits
            i = stack_begin
            while i < stack_end - word_size + 1
                word = Pointer(UInt32).new(i.to_u64).value
                # subtract to get the pointer to the header
                word -= sizeof(Kernel::GcNode)
                if word >= KERNEL_ARENA.start_addr && word <= KERNEL_ARENA.placement_addr
                    node = @@first_white_node
                    prev = Pointer(Kernel::GcNode).null
                    while !node.null?
                        if node.address.to_u32 == word
                            # word looks like a gc pointer!
                            # remove from current list
                            if !prev.null?
                                prev.value.next_node = node.value.next_node
                            else
                                @@first_white_node = node.value.next_node
                            end
                            # move it to the gray list
                            if @@first_gray_node.null?
                                node.value.next_node = Pointer(Kernel::GcNode).null
                                @@first_gray_node = node
                            else
                                node.value.next_node = @@first_gray_node
                                @@first_gray_node = node
                            end
                            Serial.puts "found: "
                            break
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
        elsif !@@first_gray_node.null?
            # second stage of marking phase: precisely marking gray nodes
            Serial.puts "second stage\n"
            type_info = @@type_info.not_nil!
            new_first_gray_node = Pointer(Kernel::GcNode).null

            node = @@first_gray_node
            while !node.null?
                Serial.puts "node: ", node, "\n"
                if node.value.magic == GC_NODE_MAGIC_ATOMIC
                    # skip atomic nodes
                    prev = node
                    node = node.value.next_node
                    next
                end

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
                        #if new_first_gray_node.null?
                        #    # first node
                        #    header.value.next_node = Pointer(Kernel::GcNode).null
                        #    new_first_gray_node = header
                        #else
                        #    # middle node
                        #    header.value.next_node = new_first_gray_node
                        #    new_first_gray_node = header
                        #end
                    end
                    pos += 1
                    offsets = offsets.unsafe_shr 1
                end

                # next it
                node = node.value.next_node

                # rechain current node to black stack
                #if @@first_black_node.null?
                #    # first node
                #    node.value.next_node = Pointer(Kernel::GcNode).null
                #    @@first_black_node = node
                #else
                #    # middle node
                #    node.value.next_node = @@first_black_node
                #    @@first_black_node = node
                #end
            end
        else
            # sweeping phase
            Serial.puts "sweeping phase?"
        end
    end

    def malloc(size : UInt32, atomic = false)
        cycle if @@enabled
        size += sizeof(Kernel::GcNode)
        header = Pointer(Kernel::GcNode).new(KERNEL_ARENA.malloc(size).to_u64)
        header.value.magic = atomic ? GC_NODE_MAGIC_ATOMIC : GC_NODE_MAGIC
        # append node to linked list
        if @@enabled
            if @@bytes_allocated == 0
                header.value.next_node = Pointer(Kernel::GcNode).null
                @@first_white_node = header
            else
                header.value.next_node = @@first_gray_node
                @@first_gray_node = header
            end
            @@bytes_allocated += size
        end
        # return
        ptr = Pointer(Void).new(header.address.to_u64 + sizeof(Kernel::GcNode))
        Serial.puts self, "\n" if @@enabled
        Serial.puts "ret: ",ptr, "\n---\n" if @@enabled
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