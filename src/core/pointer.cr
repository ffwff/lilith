private lib Kernel
    fun pmalloc(sz : UInt32) : UInt32
    fun pmalloc_a(sz : UInt32) : UInt32
end

struct Pointer(T)
    def self.null
        new 0u64
    end

    def self.pmalloc
        new (Kernel.pmalloc sizeof(T).to_u32).to_u64
    end
    def self.pmalloc_a
        new (Kernel.pmalloc_a sizeof(T).to_u32).to_u64
    end

    def [](offset : Int)
        (self + offset.to_i64).value
    end

    def []=(offset : Int, data : T)
        (self + offset.to_i64).value = data
    end

    def to_byte_ptr : UInt8*
        Pointer(UInt8).new(address)
    end

end

fun memset(dst : UInt8*, c : UInt8, n : UInt32) : UInt8*
    n.times do |i|
        dst[i] = c
    end
    dst
end