# Kernel memory allocator
# this is an implementation of a simple pool memory allocator
# each pool is 4096 bytes, and are chained together

require "../arch/paging.cr"

private MAGIC_POOL_HEADER = 0xC0FEC0FE

private lib Kernel
  @[Packed]
  struct PoolHeader
    block_buffer_size : UInt32
    next_pool : PoolHeader*
    first_free_block : PoolBlockHeader*
    magic_number : UInt32
  end

  @[Packed]
  struct PoolBlockHeader
    next_free_block : PoolBlockHeader*
  end
end

private struct Pool
  POOL_SIZE         = 0x1000
  HEADER_SIZE       = sizeof(Kernel::PoolHeader)
  BLOCK_HEADER_SIZE = sizeof(Kernel::PoolBlockHeader)

  def initialize(@header : Kernel::PoolHeader*)
    if @header.value.magic_number != MAGIC_POOL_HEADER
      panic "magic pool number is overwritten!"
    end
  end

  getter header

  # size of an object stored in each block
  def block_buffer_size
    @header.value.block_buffer_size
  end

  # full size of a block
  def block_size
    @header.value.block_buffer_size + sizeof(Kernel::PoolBlockHeader)
  end

  # how many blocks can this pool store
  def capacity
    (POOL_SIZE - HEADER_SIZE).unsafe_div block_size
  end

  # first free block in linked list
  def first_free_block
    @header.value.first_free_block
  end

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
  end

  def to_s(io)
    io.puts "Pool ", @header, " {\n"
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
    @header.value.first_free_block = block.value.next_free_block
    block.address.to_u32 + BLOCK_HEADER_SIZE
  end

  # release a free block
  def release_block(addr : UInt32)
    block = Pointer(Kernel::PoolBlockHeader).new(addr.to_u64 - BLOCK_HEADER_SIZE)
    block.value.next_free_block = @header.value.first_free_block
    @header.value.first_free_block = block
  end
end

private struct KernelArena
  # linked list free pools for sizes of 2^4, 2^5 ... 2^10
  @free_pools = uninitialized Kernel::PoolHeader*[6]
  START_ADDR = 0x1000_0000.to_u32
  @placement_addr : UInt32 = START_ADDR

  def start_addr
    START_ADDR
  end

  getter placement_addr

  # free pool chaining
  @[AlwaysInline]
  private def idx_for_pool_size(sz : UInt32)
    case sz
    when  32; 0
    when  64; 1
    when 128; 2
    when 256; 3
    when 512; 4
    else      5
    end
  end

  # pool
  private def new_pool(buffer_size : UInt32) : Pool
    addr = @placement_addr
    Paging.alloc_page_pg(@placement_addr, true, false)
    @placement_addr += 0x1000

    pool_hdr = Pointer(Kernel::PoolHeader).new(addr.to_u64)
    pool_hdr.value.block_buffer_size = buffer_size
    pool_hdr.value.next_pool = Pointer(Kernel::PoolHeader).null
    pool_hdr.value.first_free_block = Pointer(Kernel::PoolBlockHeader).new(addr.to_u64 + Pool::HEADER_SIZE)
    pool_hdr.value.magic_number = MAGIC_POOL_HEADER
    pool = Pool.new pool_hdr
    pool.init_blocks
    pool
  end

  # manual functions
  def malloc(sz : UInt32) : UInt32
    panic "only supports sizes of <= 1024" if sz > 1024
    pool_size = max(32, sz.nearest_power_of_2).to_u32
    idx = idx_for_pool_size pool_size
    if @free_pools[idx].null?
      # create a new pool if there isn't any freed
      pool = new_pool(pool_size)
      chain_pool pool
      pool.get_free_block
    else
      # reuse existing pool
      pool = Pool.new @free_pools[idx]
      if pool.first_free_block.null?
        # pop if pool is full
        # break circular chains in the tail node of linked list
        cur_pool = pool.header.value.next_pool
        while !cur_pool.null?
          next_pool = cur_pool.value.next_pool
          if cur_pool.value.first_free_block.null?
            cur_pool.value.next_pool = Pointer(Kernel::PoolHeader).null
          else
            break
          end
          cur_pool = next_pool
        end
        # have we found a free pool?
        if cur_pool.null?
          # nope, new pool
          pool = new_pool(pool_size)
          chain_pool pool
          return pool.get_free_block
        else
          return Pool.new(cur_pool).get_free_block
        end
      end
      pool.get_free_block
    end
  end

  # TODO reuse empty free pools to different size
  def free(ptr : UInt32)
    pool_hdr = Pointer(Kernel::PoolHeader).new(ptr.to_u64 & 0xFFFF_F000)
    pool = Pool.new pool_hdr
    pool.release_block ptr
    chain_pool pool
  end

  private def chain_pool(pool)
    idx = idx_for_pool_size pool.block_buffer_size
    if pool.header.value.next_pool.null?
      pool.header.value.next_pool = @free_pools[idx]
      @free_pools[idx] = pool.header
    end
  end

  # utils
  def to_s(io)
    io.puts
  end

  def block_size_for_ptr(ptr)
    pool_hdr = Pointer(Kernel::PoolHeader).new(ptr.address.to_u64 & 0xFFFF_F000)
    pool_hdr.value.block_buffer_size
  end
end

KERNEL_ARENA = KernelArena.new
