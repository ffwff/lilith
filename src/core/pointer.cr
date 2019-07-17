struct PMallocState

    @addr = 0u32
    property addr
    @start = 0u32
    property start

    def alloc(size : Int)
        last = @addr
        @addr += size.to_u32
        last
    end

    def alloca(size : Int)
        if (@addr & 0xFFFF_F000) != 0
            @addr = (@addr & 0xFFFF_F000) + 0x1000
        end
        alloc(size)
    end

end

PMALLOC_STATE = PMallocState.new

struct Pointer(T)
    def self.null
        new 0u64
    end

    # pre-pg malloc
    def self.pmalloc(size : Int)
        new PMALLOC_STATE.alloc(size).to_u64
    end
    def self.pmalloc
        pmalloc(sizeof(T))
    end
    def self.pmalloc_a
        new PMALLOC_STATE.alloca(sizeof(T)).to_u64
    end

    # pg malloc
    def self.malloc(size)
        new KERNEL_ARENA.malloc(size.to_u32).to_u64
    end
    def free
        KERNEL_ARENA.free(self.address.to_u32)
    end

    # methods
    def to_s(io)
        io.puts "[0x"
        self.address.to_s io, 16
        io.puts "]"
    end

    def null?
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

    def ==(other)
        self.address == other.address
    end
    def !=(other)
        self.address != other.address
    end

end