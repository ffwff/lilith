struct Pointer(T)

    def self.null
        new 0u64
    end

    def [](offset : Int)
        (self + offset.to_i64).value
    end

    def []=(offset : Int, data : T)
        (self + offset.to_i64).value = data
    end

end

struct StaticArray(T, N)

    def to_unsafe : Pointer(T)
        pointerof(@buffer)
    end

end

class String

    def bytes
        pointerof(@c)
    end

end

lib LibC
    alias String = UInt8*
end

macro cstring(string)
    begin
        __str = StaticArray(UInt8, {{ string.size + 1 }}).new
        {% for idx in 0..(string.size - 1) %}
        __str.to_unsafe[{{ idx }}] = {{ string }}.bytes[{{ idx }}]
        {% end %}
        __str.to_unsafe[{{ string.size }}] = 0
        __str
    end
end

macro cstrptr(string)
    cstring({{ string }}).to_unsafe
end
