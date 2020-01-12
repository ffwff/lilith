# Memory allocator used by the garbage collector, used by userspace libcrystal and the kernel.
# This is an implementation of a simple pool-based memory allocator,
# each pool is 4096 bytes, and are chained together. Pool headers include
# an allocation bitmap for fast allocation and GC metadata bitmap for faster sweep phase.
# The memory allocator can allocate for sizes from 32 up to ~4096.
#
# ### Small and large pools
#
# Each **small pool** (for sizes <= 1024) has the following layout:
#
# ```
# struct Pool
#   struct Data
#      struct Header
#        @magic     : USize
#        @next_pool : Pool*
#        @idx       : USize
#        @nfree     : USize
#      end
#      @alloc_bitmap : UInt32[...]
#      @mark_bitmap  : UInt32[...]
#      @alignment_padding : UInt32 # optional
#   end
#   @payload : UInt8[4096 - sizeof(Data)]
# end
# ```
#
# Each header holds information about the pool's identity, block size and number of free blocks.
# The payload is divided into equal spaces of N kilobytes each, where N can be determined by
# getting `Allocator::Small::SIZES[@idx]`.
#
# Allocation can be done by searching through the `alloc_bitmap` and finding the first free bit.
# The index of that bit in the bitmap determines where the block is (`payload + idx * block_size`).
# Set bits represent allocated blocks, while unset bits represent freed blocks. Allocation
# also decreases `nfree` by 1. Once nfree reaches zero, the pool is considered free and is chained
# into the global allocator free list.
#
# Marking a block can be done by setting that block's corresponding index in the `mark_bitmap`.
#
# Each **large pool** has the following layout:
#
# ```
# struct Pool
#   struct Header
#     @magic  : USize
#     @marked : USize
#     @atomic : USize
#   end
#   @payload : UInt8[4096 - sizeof(Header)]
# end
# ```
#
# Allocation is simply getting a free page, filling the headers of the page to default values.
# Marking can be done by setting `@marked` to 1.
#
# ### Allocating pools
#
# The allocator keeps track of empty pages through a linked list, forming a free stack.
# If a page can be popped from the stack, it is used as the page for a new pool. If not,
# the private method `Allocator.alloc_page` is called, getting a new page from the OS or from
# the `FrameAllocator`.
#
# ## See also
#
# See `Allocator::Small::Pool` for more information.
module Allocator::Small
  extend self

  lib Data
    MAGIC        = 0x47727530
    MAGIC_ATOMIC = 0x47727531

    struct PoolHeader
      magic : USize
      next_pool : PoolHeader*
      idx : USize
      nfree : USize
    end

    MAGIC_MMAP = 0x47727532
    MAX_MMAP_SIZE = 0x1000 - sizeof(MmapHeader)
    struct MmapHeader
      magic : USize
      marked : USize
      atomic : USize
    end

    MAGIC_EMPTY = 0
    struct EmptyHeader
      magic : USize
      next_page : EmptyHeader*
    end
  end

  # A wrapper for handling bitmapped small memory pool used by the allocator, the wrapper
  # contains a page-aligned pointer to the pool, as well as allocation sizes.
  struct Pool
    SIZE = 0x1000

    @idx = 0
    @block_size = 0
    @blocks = 0
    getter header, idx, block_size, blocks

    def initialize(@header : Data::PoolHeader*)
      @idx = @header.value.idx.to_i32
      @block_size = Allocator::Small::SIZES[@idx]
      @blocks = Allocator::Small::ITEMS[@idx]
    end

    def initialize(@header : Data::PoolHeader*, @idx : Int32)
      @block_size = Allocator::Small::SIZES[@idx]
      @blocks = Allocator::Small::ITEMS[@idx]
    end

    # Checks if the pool has correct magic numbers.
    def validate_header
      if @header.value.magic != Data::MAGIC &&
         @header.value.magic != Data::MAGIC_ATOMIC
        # Serial.print @header, '\n'
        abort "magic pool number is overwritten!"
      end
    end

    # Gets the number of free blocks.
    def nfree
      @header.value.nfree
    end

    # Initializes the header, this must be called after the page for the pool is allocated.
    def init_header(atomic = false)
      @header.value.magic = atomic ? Data::MAGIC_ATOMIC : Data::MAGIC
      @header.value.next_pool = Pointer(Data::PoolHeader).null
      @header.value.idx = @idx
      @header.value.nfree = @blocks
      alloc_bitmap.clear
      mark_bitmap.clear
    end

    # Returns the allocation bitmap.
    def alloc_bitmap
      BitArray
        .new((@header.as(Void*) + sizeof(Data::PoolHeader)).as(UInt32*),
          blocks)
    end

    # Returns the mark bitmap.
    def mark_bitmap
      BitArray
        .new((@header.as(Void*) +
              sizeof(Data::PoolHeader) +
              BitArray.malloc_size(@blocks)*4).as(UInt32*),
          blocks)
    end

    # Returns the aligment padding's size.
    def alignment_padding
      @block_size >= MIN_SIZE_TO_ALIGN ? 8 : 0
    end

    # Gets the block corresponding to `idx` in the allocation bitmap.
    def block(idx : Int)
      (@header.as(Void*) +
        sizeof(Data::PoolHeader) +
        BitArray.malloc_size(@blocks)*4*2 +
        alignment_padding +
        idx * @block_size)
    end

    private def relative_addr(ptr)
      ptr.address - @header.address - alignment_padding - BitArray.malloc_size(@blocks)*4*2 - sizeof(Data::PoolHeader)
    end

    def make_markable(block : Void*)
      rem = relative_addr(block) & (@block_size - 1)
      new_ptr = Pointer(Void).new(block.address - rem.to_u64)
      return nil if block_marked?(block)
      mark_block(block, true)
      new_ptr
    end

    # Gets the corresponding index for the block.
    def idx_for_block(block : Void*)
      relative_addr(block) >> (@idx + MIN_POW2)
    end

    # Gets the first free block in the allocation bitmap,
    def get_free_block : Void*
      if (idx = alloc_bitmap.first_unset) != -1
        @header.value.nfree = nfree - 1
        alloc_bitmap[idx] = true
        block(idx)
      else
        Pointer(Void).null
      end
    end

    # Sets the corresponding element for the block to zero, freeing  the block.
    def release_block(block : Void*)
      idx = idx_for_block(block)
      alloc_bitmap[idx] = false
      @header.value.nfree = nfree + 1
    end

    # Marks the block.
    def mark_block(block : Void*, val : Bool)
      idx = idx_for_block(block)
      mark_bitmap[idx] = val
    end

    # Checks if the block is marked.
    def block_marked?(block : Void*)
      idx = idx_for_block(block)
      unless 0 <= idx < mark_bitmap.size
        return true
      end
      mark_bitmap[idx]
    end

    # Performs a sweep.
    def sweep
      {% if false %}
        idx = 0
        mark_bitmap.each do |bit|
          if !bit && alloc_bitmap[idx]
            ptr = block(idx)
            Serial.print "free: ", ptr, ' ', ptr.as(Int32*).value, '\n'
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

  # Minimum pool block size for the alignment padding to appear.
  MIN_SIZE_TO_ALIGN = 128

  # Binary log of the smallest size the allocator can allocate.
  MIN_POW2          =   5

  # Sizes of a small pool, according to its `@idx`.
  SIZES = StaticArray[32, 64, 128, 256, 512, 1024]

  # Maximum size for the allocating a small pool.
  MAX_POOL_SIZE = 1024

  # Maximum number of blocks a pool of a given `@idx` can store
  ITEMS = StaticArray[126, 63, 31, 15, 7, 3]

  # Placement address of first pool
  @@start_addr = 0u64

  # Placement address of newest pool
  class_getter placement_addr
  @@placement_addr = 0u64

  # Number of pages the allocator has allocated (number of mmap calls/frames claimed).
  class_getter pages_allocated
  @@pages_allocated = 0

  # available pool list
  @@pools = uninitialized Data::PoolHeader*[7]
  # available pool list (atomic)
  @@atomic_pools = uninitialized Data::PoolHeader*[7]
  # empty, reusable pages
  @@empty_pages = Pointer(Data::EmptyHeader).null

  # Initializes the memory allocator.
  def init(@@placement_addr)
    @@start_addr = @@placement_addr
    @@pools.size.times do |i|
      @@pools[i] = Pointer(Data::PoolHeader).null
      @@atomic_pools[i] = Pointer(Data::PoolHeader).null
    end
  end

  def contains_ptr?(ptr)
    @@start_addr <= ptr.address < @@placement_addr
  end

  # Rounds a pointer to the nearest block in a pool
  def make_markable(ptr : Void*) : Void*?
    return if @@pages_allocated == 0
    addr = ptr.address & 0xFFFF_FFFF_FFFF_F000
    magic = Pointer(USize).new(addr).value
    if magic == Data::MAGIC || magic == Data::MAGIC_ATOMIC
      hdr = Pointer(Data::PoolHeader).new(addr)
      Pool.new(hdr).make_markable ptr
    elsif magic == Data::MAGIC_MMAP
      hdr = Pointer(Data::MmapHeader).new(addr)
      return if hdr.value.marked == 1
      Pointer(Void).new(addr + sizeof(Data::MmapHeader))
    end
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
      alloc_page addr
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

  private def new_mmap(bytes : Int, atomic)
    pool_size = sizeof(Data::MmapHeader) + bytes
    abort "pool size must be <= 0x1000" if pool_size > Pool::SIZE

    if page = @@empty_pages
      addr = page.address
      @@empty_pages = page.value.next_page
    else
      addr = @@placement_addr
      alloc_page addr
      @@placement_addr += Pool::SIZE
    end

    hdr = Pointer(Data::MmapHeader).new(addr)
    hdr.value.magic = Data::MAGIC_MMAP
    hdr.value.marked = 0
    hdr.value.atomic = atomic ? 1 : 0

    (hdr + 1).as(Void*)
  end

  # Allocates some bytes with optional `atomic` flag.
  def malloc(bytes : Int, atomic = false) : Void*
    if bytes > Data::MAX_MMAP_SIZE
      abort "can't allocate that large a block"
    elsif bytes > MAX_POOL_SIZE
      return new_mmap(bytes, atomic)
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

  # Marks the pointer.
  def mark(ptr : Void*, val = true)
    # Serial.print "mark: ", ptr, '\n'
    addr = ptr.address & 0xFFFF_FFFF_FFFF_F000
    magic = Pointer(USize).new(addr).value
    if magic == Data::MAGIC || magic == Data::MAGIC_ATOMIC
      hdr = Pointer(Data::PoolHeader).new(addr)
      Pool.new(hdr).mark_block ptr, val
    elsif magic == Data::MAGIC_MMAP
      hdr = Pointer(Data::MmapHeader).new(addr)
      hdr.value.marked = val ? 1 : 0
    else
      abort "mark: unknown magic"
    end
  end

  # Checks if the pointer is marked.
  def marked?(ptr : Void*)
    addr = ptr.address & 0xFFFF_FFFF_FFFF_F000
    magic = Pointer(USize).new(addr).value
    if magic == Data::MAGIC || magic == Data::MAGIC_ATOMIC
      hdr = Pointer(Data::PoolHeader).new(addr)
      Pool.new(hdr).block_marked? ptr
    elsif magic == Data::MAGIC_MMAP
      hdr = Pointer(Data::MmapHeader).new(addr)
      hdr.value.marked == 1
    else
      abort "mark: unknown magic"
    end
  end

  # Checks if the pointer is atomic.
  def atomic?(ptr : Void*)
    addr = ptr.address & 0xFFFF_FFFF_FFFF_F000
    magic = Pointer(USize).new(addr).value
    case magic
    when Data::MAGIC_ATOMIC
      true
    when Data::MAGIC_MMAP
      Pointer(Data::MmapHeader).new(addr).value.atomic == 1
    else
      false
    end
  end

  # Sweeps the heap. This done by:
  #   1. Resetting the list of free pools to null
  #   2. Loops through every page of the heap. If it's a **small pool**, perform a binary and operation between each bit of the `alloc_bitmap` and `mark_bitmap`, and clear the `mark_bitmap`. If it's a **large pool**, free the pool if it is marked.
  #   3. Rechain each of the pool into the list of free pools.
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
        if hdr.value.marked == 0
          hdr = Pointer(Data::EmptyHeader).new(addr)
          hdr.value.magic = 0
          hdr.value.next_page = @@empty_pages
          @@empty_pages = hdr
        end
      end
      addr += 0x1000
    end
  end

  # Dumps the entire heap for easier debugging.
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

  # Gets the block size of the pool containing `ptr`.
  def block_size_for_ptr(ptr)
    addr = ptr.address & 0xFFFF_FFFF_FFFF_F000
    magic = Pointer(USize).new(addr).value
    if magic == Data::MAGIC || magic == Data::MAGIC_ATOMIC
      hdr = Pointer(Data::PoolHeader).new(ptr.address & 0xFFFF_FFFF_FFFF_F000)
      Pool.new(hdr).block_size
    elsif magic == Data::MAGIC_MMAP
      Data::MAX_MMAP_SIZE
    else
      abort
    end
  end

  {% if flag?(:kernel) %}
    private def alloc_page(addr)
      @@pages_allocated += 1
      if process = Multiprocessing::Scheduler.current_process
        if process.kernel_process? && !Syscall.locked
          return Paging.alloc_page_drv addr, true, false
        end
      end
      Paging.alloc_page addr, true, false
    end
  {% else %}
    private def alloc_page(addr)
      @@pages_allocated += 1
      LibC.mmap Pointer(Void).new(addr), 0x1000, (LibC::MmapProt::Read | LibC::MmapProt::Write).value, 0, -1, 0
    end
  {% end %}
end
