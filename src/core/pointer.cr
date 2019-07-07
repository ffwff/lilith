private lib Kernel
    fun pmalloc(sz : UInt32) : UInt32
    fun pmalloc_a(sz : UInt32) : UInt32
end

struct Pointer(T)
    def self.null
        new 0u64
    end

    # pre-pg malloc
    def self.pmalloc
        new (Kernel.pmalloc sizeof(T).to_u32).to_u64
    end
    def self.pmalloc(size : Int)
        new Kernel.pmalloc(size).to_u64
    end
    def self.pmalloc_a
        new (Kernel.pmalloc_a sizeof(T).to_u32).to_u64
    end

    # methods
    def to_s(io)
        io.puts "[0x"
        self.address.to_s io, 16
        io.puts "]"
    end

    def is_null
        self.address == 0
    end

    # operators
    def [](offset : Int)
        (self + offset.to_i64).value
    end

    def []=(offset : Int, data : T)
        (self + offset.to_i64).value = data
    end

    def +(offset : Int)
        self + offset.to_i64
    end
    def -(offset : Int)
        self - offset.to_i64
    end

end