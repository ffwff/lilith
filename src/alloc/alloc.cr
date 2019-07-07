# Kernel memory allocator
# this is an implementation of a simple pool memory allocator
# each pool is 4096 bytes, and are chained together

require "../arch/paging.cr"

private lib Kernel

    @[Packed]
    struct PoolHeader
        block_buffer_size : UInt32
        next_pool : PoolHeader*
        first_free_block : PoolBlockHeader*
        padding : UInt32
    end

    @[Packed]
    struct PoolBlockHeader
        next_free_block : PoolBlockHeader*
    end

end

struct Pool

    POOL_SIZE = 0x1000
    HEADER_SIZE = sizeof(Kernel::PoolHeader)
    def initialize(@header : Kernel::PoolHeader*); end

    # size of an object stored in each block
    def block_buffer_size; @header.value.block_buffer_size; end

    # full size of a block
    def block_size; @header.value.block_buffer_size + sizeof(Kernel::PoolBlockHeader); end

    # how many blocks can this pool store
    def capacity; (POOL_SIZE - HEADER_SIZE).unsafe_div block_size; end

    # first free block in linked list
    def first_free_block; @header.value.first_free_block; end
    def first_free_block=(x : PoolBlockHeader*); @header.value.first_free_block = x; end

    # methods
    def init_blocks
        # NOTE: first_free_block must be set before doing this
        i = first_free_block.address.to_u32
        end_addr = @header.address.to_u32 + 0x1000 - block_size * 2
        # fill next_free_block field of all except last one
        while i < end_addr
            ptr = Pointer(Kernel::PoolBlockHeader).new i.to_u64
            ptr.value.next_free_block = Pointer(Kernel::PoolBlockHeader).new(i.to_u64 + block_size)
            i += block_size
        end
        # fill last one with zero
        ptr = Pointer(Kernel::PoolBlockHeader).new i.to_u64
        ptr.value.next_free_block = Pointer(Kernel::PoolBlockHeader).null
        Serial.puts ptr, "\n"
    end

    def to_s(io)
        io.puts "Pool " , @header , " {\n"
        io.puts " header_size: ", HEADER_SIZE, "\n"
        io.puts " block_buffer_size: ", block_buffer_size, "\n"
        io.puts " capacity: ", capacity, "\n"
        io.puts " first_free_block: ", first_free_block, "\n"
        io.puts "}\n"
    end

    # obtain a free block and pop it from the pool
    # returns a pointer to the buffer
    def get_free_block : UInt32
        block = first_free_block
        first_free_block = block.value.next_free_block
        block.addr.to_u32 + HEADER_SIZE
    end

    # release a free block
    def release_block(addr : UInt32)
        block = Pointer(Kernel::PoolBlockHeader).new(addr - HEADER_SIZE)
        block.value.next = first_free_block
        first_free_block = block
    end


end

struct KernelArena
    @first_pool = Pointer(Kernel::PoolHeader).null
    @last_pool  = Pointer(Kernel::PoolHeader).null
    @placement_addr : UInt32 = 0x1000_0000

    # expose
    def new_pool(size : UInt32) : Pool
        addr = @placement_addr
        Paging.alloc_page_pg(@placement_addr, true, false)
        @placement_addr += 0x1000

        pool_hdr = Pointer(Kernel::PoolHeader).new(addr.to_u64)
        pool_hdr.value.block_buffer_size = size
        pool_hdr.value.next_pool = Pointer(Kernel::PoolHeader).null
        pool_hdr.value.first_free_block = Pointer(Kernel::PoolBlockHeader).new(addr.to_u64 + Pool::HEADER_SIZE)
        if @first_pool.is_null
            @first_pool = @last_pool = pool_hdr
        else
            @last_pool.value.next_pool = pool_hdr
            @last_pool = pool_hdr
        end
        pool = Pool.new @last_pool
        pool.init_blocks
        pool
    end

    # manual functions
    def malloc(sz : UInt32) : UInt32
        pool = new_pool(4)
        Serial.puts pool
        0.to_u32
    end

    def free(ptr : UInt32)
    end

end

KERNEL_ARENA = KernelArena.new