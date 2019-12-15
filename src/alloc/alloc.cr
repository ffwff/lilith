# Kernel memory allocator
# this is an implementation of a simple pool memory allocator
# each pool is 4096 bytes, and are chained together

require "../arch/paging.cr"

module Arena
  extend self

  lib Data
    MAGIC = 0x47727530
    MAGIC_ATOMIC = 0x47727531
    struct PoolHeader
      magic : USize
      next_pool : PoolHeader*
      idx : USize
      nfree : USize
    end

    MAGIC_MMAP = 0x47727532
    struct MmapHeader
      magic : USize
      marked : USize
    end

    MAGIC_EMPTY = 0
    struct EmptyHeader
      magic : USize
      next_page : EmptyHeader*
    end
  end

  # a bitmapped memory pool
  # [ hdr ][ alloc_bitmap ][ mark_bitmap ]( x * sz )
  struct Pool
    SIZE = 0x1000

    @idx = 0
    @block_size = 0
    @blocks = 0
    getter header, idx, block_size, blocks

    def initialize(@header : Data::PoolHeader*)
      @idx = @header.value.idx.to_i32
      @block_size = Arena::SIZES[@idx]
      @blocks = Arena::ITEMS[@idx]
    end

    def validate_header
      if @header.value.magic != Data::MAGIC &&
         @header.value.magic != Data::MAGIC_ATOMIC
        Serial.print @header, '\n'
        panic "magic pool number is overwritten!"
      end
    end

    def initialize(@header : Data::PoolHeader*, @idx : Int32)
      @block_size = Arena::SIZES[@idx]
      @blocks = Arena::ITEMS[@idx]
    end

    def nfree
      @header.value.nfree
    end

    def init_header(atomic=false)
      @header.value.magic = atomic ? Data::MAGIC_ATOMIC : Data::MAGIC
      @header.value.next_pool = Pointer(Data::PoolHeader).null
      @header.value.idx = @idx
      @header.value.nfree = @blocks
      alloc_bitmap.clear
      mark_bitmap.clear
    end

    def alloc_bitmap
      BitArray
        .new((@header.as(Void*) + sizeof(Data::PoolHeader)).as(UInt32*),
          blocks)
    end

    def mark_bitmap
      BitArray
        .new((@header.as(Void*) +
            sizeof(Data::PoolHeader) +
            BitArray.malloc_size(@blocks)*4).as(UInt32*),
          blocks)
    end

    def alignment_padding
      @block_size >= MIN_SIZE_TO_ALIGN ? 8 : 0
    end

    def block(idx : Int)
      (@header.as(Void*) +
        sizeof(Data::PoolHeader) +
        BitArray.malloc_size(@blocks)*4*2 +
        alignment_padding +
        idx * @block_size)
    end

    def aligned?(block : Void*)
      (block.address - @header.address - alignment_padding - BitArray.malloc_size(@blocks)*4*2 - sizeof(Data::PoolHeader)) % @block_size == 0
    end

    def idx_for_block(block : Void*)
      (block.address - @header.address - alignment_padding - BitArray.malloc_size(@blocks)*4*2 - sizeof(Data::PoolHeader)) // @block_size
    end

    def get_free_block : Void*
      if (idx = alloc_bitmap.first_unset) != -1
        @header.value.nfree = nfree - 1
        alloc_bitmap[idx] = true
        block(idx)
      else
        Pointer(Void).null
      end
    end

    def release_block(block : Void*)
      idx = idx_for_block(block)
      panic "double free" if !alloc_bitmap[idx]
      alloc_bitmap[idx] = false
      @header.value.nfree = nfree + 1
    end

    def mark_block(block : Void*)
      idx = idx_for_block(block)
      mark_bitmap[idx] = true
    end

    def block_marked?(block : Void*)
      idx = idx_for_block(block)
      unless 0 <= idx && idx < mark_bitmap.size
        return true
      end
      mark_bitmap[idx]
    end

    def sweep
      {% if false %}
        idx = 0
        mark_bitmap.each do |bit|
          if !bit && alloc_bitmap[idx]
            ptr = block(idx)
            Serial.print "free: ", ptr, '\n'
            breakpoint if ptr.address == 0xffff80800015f3a8u64
          end
          idx += 1
        end
      {% end %}
      alloc_bitmap.mask mark_bitmap
      mark_bitmap.clear
      @header.value.nfree = @blocks - alloc_bitmap.popcount
    end

    def to_s(io)
      io.print "Pool ", @header.value.magic == Data::MAGIC_ATOMIC ? "(atomic) " : "", @header, " {\n"
      io.print "  size: ", @block_size, "\n"
      io.print "  nfree: ", nfree, "/", @blocks, "\n"
      io.print "  alloc: ", alloc_bitmap, "\n"
      io.print "  mark: ", mark_bitmap, "\n"
      io.print "}\n"
    end
  end

  # all blocks must be 16-bytes aligned
  MIN_SIZE_TO_ALIGN = 128

  # sizes of a pool
  SIZES = StaticArray[32, 64, 128, 256, 512, 1024]
  # maximum pool size
  MAX_POOL_SIZE = 1024
  # maximum number of blocks a given pool can store
  ITEMS = StaticArray[126, 63, 31, 15, 7, 3]
  # placement address of first pool
  @@start_addr = 0u64
  # placement address of new pool
  @@placement_addr = 0u64
  # available pool list
  @@pools = uninitialized Data::PoolHeader*[7]
  # available pool list (atomic)
  @@atomic_pools = uninitialized Data::PoolHeader*[7]
  # empty, reusable pages
  @@empty_pages = Pointer(Data::EmptyHeader).null

  def init(@@placement_addr)
    @@start_addr = @@placement_addr
    @@pools.size.times do |i|
      @@pools[i] = Pointer(Data::PoolHeader).null
    end
  end

  def aligned?(ptr : Void*)
    addr = ptr.address & 0xFFFF_FFFF_FFFF_F000
    magic = Pointer(USize).new(addr).value
    if magic == Data::MAGIC || magic == Data::MAGIC_ATOMIC
      hdr = Pointer(Data::PoolHeader).new(addr)
      Pool.new(hdr).aligned? ptr
    elsif magic == Data::MAGIC_MMAP
      panic "TODO"
    else
      false
    end
  end

  def contains_ptr?(ptr)
    @@start_addr <= ptr.address && ptr.address < @@placement_addr && aligned?(ptr)
  end

  private def pool_for_bytes(bytes : Int)
    idx = 0
    SIZES.each do |size|
      return idx if bytes <= size
      idx += 1
    end
    -1
  end

  private def new_pool(idx : Int, atomic)
    if page = @@empty_pages
      addr = page.address
      @@empty_pages = page.value.next_page
    else
      addr = @@placement_addr
      Paging.alloc_page_pg addr, true, false
      @@placement_addr += Pool::SIZE
    end

    hdr = Pointer(Data::PoolHeader).new(addr)
    if atomic
      @@atomic_pools[idx] = hdr
    else
      @@pools[idx] = hdr
    end

    pool = Pool.new hdr, idx
    pool.init_header atomic
    pool
  end

  private def new_mmap(bytes : Int)
    pool_size = sizeof(Data::MmapHeader) + bytes
    panic "pool size must be <= 0x1000" if pool_size > 0x1000

    addr = @@placement_addr
    Paging.alloc_page_pg addr, true, false
    @@placement_addr += 0x1000

    hdr = Pointer(Data::MmapHeader).new(addr)
    hdr.value.magic = Data::MAGIC_MMAP
    hdr.value.marked = 0

    (hdr + 1).as(Void*)
  end

  def malloc(bytes : Int, atomic=false) : Void*
    if bytes > MAX_POOL_SIZE
      return new_mmap bytes
    end
    idx = pool_for_bytes bytes
    # NOTE: atomic_pools/pools is passed on the stack
    pools = atomic ? @@atomic_pools.to_unsafe : @@pools.to_unsafe
    if pools[idx].null?
      pool = new_pool idx, atomic
      # Serial.print "NEW: ", pool
      pool.get_free_block
    else
      pool = Pool.new pools[idx]
      # Serial.print "OLD: ", pool
      pool.validate_header
      block = pool.get_free_block
      if pool.nfree == 0
        # if we can't allocate a new block in the pool, unchain it
        pools[idx] = pool.header.value.next_pool
        pool.header.value.next_pool = Pointer(Data::PoolHeader).null
      end
      block
    end
  end

  def mark(ptr : Void*)
    # Serial.print "mark: ", ptr, '\n'
    addr = ptr.address & 0xFFFF_FFFF_FFFF_F000
    magic = Pointer(USize).new(addr).value
    if magic == Data::MAGIC || magic == Data::MAGIC_ATOMIC
      hdr = Pointer(Data::PoolHeader).new(addr)
      Pool.new(hdr).mark_block ptr
    elsif magic == Data::MAGIC_MMAP
      hdr = Pointer(Data::MmapHeader).new(addr)
      hdr.value.marked = 1
    else
      panic "mark: unknown magic"
    end
  end

  def marked?(ptr : Void*)
    addr = ptr.address & 0xFFFF_FFFF_FFFF_F000
    magic = Pointer(USize).new(addr).value
    if magic == Data::MAGIC || magic == Data::MAGIC_ATOMIC
      hdr = Pointer(Data::PoolHeader).new(addr)
      Pool.new(hdr).block_marked? ptr
    elsif magic == Data::MAGIC_MMAP
      hdr = Pointer(Data::MmapHeader).new(addr)
      hdr.value.marked == 1 ? true : false
    else
      true
    end
  end

  def atomic?(ptr : Void*)
    addr = ptr.address & 0xFFFF_FFFF_FFFF_F000
    magic = Pointer(USize).new(addr).value
    magic == Data::MAGIC_ATOMIC
  end

  def sweep
    @@pools.size.times do |i|
      @@pools[i] = Pointer(Data::PoolHeader).null
    end
    @@atomic_pools.size.times do |i|
      @@atomic_pools[i] = Pointer(Data::PoolHeader).null
    end
    addr = @@start_addr
    while addr < @@placement_addr.to_u64
      magic = Pointer(USize).new(addr).value
      if magic == Data::MAGIC || magic == Data::MAGIC_ATOMIC
        # NOTE: atomic_pools/pools is passed on the stack
        pools = (magic == Data::MAGIC ? @@pools.to_unsafe : @@atomic_pools.to_unsafe)
        hdr = Pointer(Data::PoolHeader).new(addr)
        pool = Pool.new(hdr)
        pool.sweep
        if pool.nfree == pool.blocks
          hdr = Pointer(Data::EmptyHeader).new(addr)
          hdr.value.magic = 0
          hdr.value.next_page = @@empty_pages
          @@empty_pages = hdr
        elsif pool.nfree > 0
          hdr.value.next_pool = pools[pool.idx]
          pools[pool.idx] = hdr
        end
      elsif magic == Data::MAGIC_MMAP
        hdr = Pointer(Data::MmapHeader).new(addr)
        # TODO
      end
      addr += 0x1000
    end
  end

  def dump
    addr = @@start_addr
    while addr < @@placement_addr.to_u64
      magic = Pointer(USize).new(addr).value
      if magic == Data::MAGIC || magic == Data::MAGIC_ATOMIC
        hdr = Pointer(Data::PoolHeader).new(addr)
        pool = Pool.new(hdr)
        Serial.print pool
      elsif magic == Data::MAGIC_MMAP
      end
      addr += 0x1000
    end
  end

  def block_size_for_ptr(ptr)
    hdr = Pointer(Data::PoolHeader).new(ptr.address & 0xFFFF_FFFF_FFFF_F000)
    Pool.new(hdr).block_size
  end

end
