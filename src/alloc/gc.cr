# NOTE! We dont have write barriers

require "./alloc.cr"

abstract class Gc
end

struct GcPointer(T)

    getter ptr

    def initialize(@ptr : Pointer(T))
    end

    def self.malloc
        new LibGc.unsafe_malloc(sizeof(T), false)
    end
    def self.malloc(size)
        {% raise "must not be garbage collected type" if T < Gc %}
        new LibGc.unsafe_malloc(size.to_u32 * sizeof(T), true).as(Pointer(T))
    end

end

GC_ARRAY_HEADER_TYPE = 0xFFFF_FFFFu32
GC_ARRAY_HEADER_SIZE = 8

class GcArray(T) < Gc

    GC_GENERIC_TYPES = [
        GcArray(MemMapNode),
        GcArray(FileDescriptor),
        GcArray(AtaDevice)
    ]
    # one long for typeid, one long for length
    @size : Int32 = 0
    getter size
    def initialize(@size : Int32)
        malloc_size = @size.to_u32 * sizeof(Void*) + GC_ARRAY_HEADER_SIZE
        @ptr = LibGc.unsafe_malloc(malloc_size).as(UInt32*)
        @ptr[0] = GC_ARRAY_HEADER_TYPE
        @ptr[1] = @size.to_u32
    end

    private def buffer
        (@ptr+2).as(T*)
    end

    def [](idx : Int) : T | Nil
        panic "GcArray: out of range" if idx < 0 && idx > @size
        if buffer.as(UInt32*)[idx] == 0
            nil
        else
            buffer[idx]
        end
    end

    def []=(idx : Int, value : T)
        panic "GcArray: out of range" if idx < 0 && idx > @size
        buffer[idx] = value
    end

    private def resize(new_size)
        if new_size < @size
            panic "unimplemented!"
        end
        bufsize = KERNEL_ARENA.block_size_for_ptr(buffer.address.to_u32)
        malloc_size = new_size * sizeof(Void*) + GC_ARRAY_HEADER_SIZE
        if bufsize >= malloc_size + sizeof(Kernel::GcNode)
            # arena block supports this, grow to new size
            ptr = buffer.as(UInt32*)
            ptr[1] = new_size
            @size = new_size
        else
            # arena can't support this, allocate a new one and copy it over
            # malloc new buffer
            ptr = LibGc.unsafe_malloc(malloc_size).as(UInt32*)
            ptr[0] = GC_ARRAY_HEADER_TYPE
            ptr[1] = new_size
            new_buffer = Pointer(T).new((ptr.address + GC_ARRAY_HEADER_SIZE).to_u64)
            # copy over
            i = 0
            while i < @size
                new_buffer[i] = buffer[i]
                i += 1
            end
            # set buffer
            buffer = new_buffer
            size = new_size
        end
    end

end


# ---

fun __crystal_malloc64(size : UInt64) : Void*
    LibGc.unsafe_malloc size.to_u32
end

fun __crystal_malloc_atomic64(size : UInt64) : Void*
    LibGc.unsafe_malloc size.to_u32, true
end

# white nodes
private GC_NODE_MAGIC = 0x45564100
private GC_NODE_MAGIC_ATOMIC = 0x45564101
# gray nodes
private GC_NODE_MAGIC_GRAY = 0x45564102
private GC_NODE_MAGIC_GRAY_ATOMIC = 0x45564103
# black
private GC_NODE_MAGIC_BLACK = 0x45564104
private GC_NODE_MAGIC_BLACK_ATOMIC = 0x45564105

private lib Kernel

    struct GcNode
        next_node : GcNode*
        magic : UInt32
    end

end

module LibGc
    extend self

    TYPE_ID_SIZE = sizeof(UInt32)
    @@first_white_node = Pointer(Kernel::GcNode).null
    @@first_gray_node  = Pointer(Kernel::GcNode).null
    @@first_black_node = Pointer(Kernel::GcNode).null
    @@enabled = false
    @@root_scanned = false

    struct TypeInfo
        def initialize(@offsets : UInt32, @size : UInt32); end
        def offsets; @offsets; end
        def size; @size; end

        def to_s(io)
            io.puts "<", offsets, ",", size, ">"
        end
    end

    def init(@@data_start : UInt32, @@data_end : UInt32, @@stack_end : UInt32)
        @@type_info = BTree(UInt32, TypeInfo).new
        type_info = @@type_info.not_nil!
        offsets : UInt32 = 0
        n_classes = 0
        {% for klass in Gc.all_subclasses %}
            {% if !klass.abstract? %}
                offsets = 0
                # set zero offset if any of the field isn't 32-bit aligned
                zero_offset = false
                {%
                # HACK: crystal doesn't provide us with a list of type variables derived generic types:
                # i.e. GcArray(UInt32), GcArray(Void), etc...
                # so the user will have to provide it to us in the GC_GENERIC_TYPES constant
                type_names = [klass]
                if !klass.type_vars.empty?
                    if klass.type_vars.all?{|i| i.class_name == "MacroId" }
                        type_names = klass.constant("GC_GENERIC_TYPES")
                    else
                        type_names = [] of TypeNode
                    end
                end
                %}
                {% for type_name in type_names %}
                    {% for ivar in klass.instance_vars %}
                        {% if ivar.type < Gc || ivar.type < GcPointer ||
                            ivar.type < GcArray ||
                            (ivar.type.union? && ivar.type.union_types.any? {|x| x < Gc }) %}
                            {% puts type_name.stringify + " = " + ivar.stringify + " <" + ivar.type.stringify + ">" %}
                            if offsetof({{ type_name }}, @{{ ivar }}).unsafe_mod(4) == 0
                                field_offset = offsetof({{ type_name }}, @{{ ivar }}).unsafe_div(4)
                                debug "{{ ivar.type }}: ", offsetof({{ type_name }}, @{{ ivar }}), " ", "{{ ivar.type }}", " ", sizeof({{ ivar.type }}), "\n"
                                panic "struct pointer outside of 32-bit range!" if field_offset > 32
                                offsets |= 1.unsafe_shl(field_offset)
                            else
                                zero_offset = true
                            end
                        {% end %}
                    {% end %}
                    type_id = {{ type_name }}.crystal_instance_type_id.to_u32
                    debug "{{ type_name }} id: ", type_id, ", ", offsets, "\n"
                    value = if zero_offset
                        TypeInfo.new(0, instance_sizeof({{ type_name }}).to_u32)
                    else
                        TypeInfo.new(offsets, instance_sizeof({{ type_name }}).to_u32)
                    end
                    n_classes += 1
                    type_info.insert(type_id, value)
                {% end %}
            {% end %}
        {% end %}
        type_info.balance n_classes
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
                #debug Pointer(Void).new(word.to_u64), found ? " (found)" : "", "\n"
            end
            i += 1
        end
        fix_white
    end

    def cycle
        # marking phase
        if !@@root_scanned
            # we don't have any gray/black nodes at the beginning of a cycle
            # conservatively scan the stack for pointers
            # Serial.puts @@data_start, ' ', @@data_end, '\n'
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
                    debug "skip\n"
                    node.value.magic = GC_NODE_MAGIC_BLACK_ATOMIC
                    node = node.value.next_node
                    next
                end

                debug "magic: ", node, node.value.magic, "\n"
                panic "invariance broken" if node.value.magic == GC_NODE_MAGIC || node.value.magic == GC_NODE_MAGIC_ATOMIC

                node.value.magic = GC_NODE_MAGIC_BLACK

                buffer_addr = node.address.to_u64 + sizeof(Kernel::GcNode) + TYPE_ID_SIZE
                # get its type id
                type_id = Pointer(UInt32).new(node.address.to_u64 + sizeof(Kernel::GcNode))[0]
                debug "type: ", type_id, "\n"
                # handle gc array
                if type_id == GC_ARRAY_HEADER_TYPE
                    len = Pointer(UInt32).new(node.address.to_u64 + sizeof(Kernel::GcNode))[1]
                    i = 0
                    start = Pointer(UInt32).new(node.address.to_u64 + sizeof(Kernel::GcNode) + GC_ARRAY_HEADER_SIZE)
                    while i < len
                        addr = start[i]
                        if addr != 0
                            # mark the header as gray
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
                        i += 1
                    end
                    node = node.value.next_node
                    next
                end
                # lookup its offsets
                info = type_info.search(type_id).not_nil!
                offsets, size = info.offsets, info.size
                if offsets == 0
                    # there is no offset found for this type, yet it's not atomic
                    # then conservatively scan the region
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
                            unless addr >= KERNEL_ARENA.start_addr && addr <= KERNEL_ARENA.placement_addr
                                # must be a nil union, skip
                                pos += 1
                                offsets = offsets.unsafe_shr 1
                                next
                            end

                            # mark the header as gray
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
                debug "fix white nodes\n"
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
                debug "sweeping phase: ", self, "\n"
                node = @@first_white_node
                while !node.null?
                    panic "invariance broken" unless node.value.magic == GC_NODE_MAGIC || node.value.magic == GC_NODE_MAGIC_ATOMIC
                    Serial.puts "free ", node, " ", (node.as(UInt8*)+8) ," ", (node.as(UInt8*)+8).as(UInt32*)[0], "\n"
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

    def unsafe_malloc(size : UInt32, atomic = false)
        if @@enabled
            cycle
        end
        size += sizeof(Kernel::GcNode)
        header = Pointer(Kernel::GcNode).new(KERNEL_ARENA.malloc(size).to_u64)
        # move the barrier forwards by immediately graying out the header
        header.value.magic = atomic ? GC_NODE_MAGIC_GRAY_ATOMIC : GC_NODE_MAGIC_GRAY
        # append node to linked list
        if @@enabled
            push(@@first_gray_node, header)
        end
        # return
        ptr = Pointer(Void).new(header.address.to_u64 + sizeof(Kernel::GcNode))
        debug self, '\n' if @@enabled
        ptr
    end

    # printing
    private def out_nodes(io, first_node)
        node = first_node
        while !node.null?
            ptr = (node + 1).as(UInt32*)
            io.puts node, " (", ptr[0], ")"
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
        return
        Serial.puts *args
    end

end