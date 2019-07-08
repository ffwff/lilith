require "./alloc.cr"

class Gc; end

fun __crystal_malloc64(_size : UInt64) : Void*
    size = _size.to_u32
    ptr = Pointer(Void).new(KERNEL_ARENA.malloc(size).to_u64)
    #Serial.puts ptr
    ptr
end

fun __crystal_malloc_atomic64(_size : UInt64) : Void*
    size = _size.to_u32
    ptr = Pointer(Void).new(KERNEL_ARENA.malloc(size).to_u64)
    #Serial.puts "ptr: ", ptr, "\n"
    ptr
end

module LibGc
    extend self

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
                    # Serial.puts "offset @{{ ivar }}: ", field_offset, "\n"
                    offsets |= 1.unsafe_shl(field_offset)
                {% end %}
            {% end %}
            type_info.insert({{ klass }}.crystal_instance_type_id.to_u32, offsets)
        {% end %}
        # Serial.puts type_info, "\n"
    end

end