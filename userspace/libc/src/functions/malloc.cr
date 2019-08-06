# simple free-list based memory allocator
# reference: https://moss.cs.iit.edu/cs351/slides/slides-malloc.pdf
private struct Malloc

  MAGIC = 0x1badc0fe
  MAGIC_FREE = 0x2badc0fe
  FOOTER_MAGIC = 0x1badb011
  ALLOC_UNIT = 0x1000u32

  def unit_aligned(sz : UInt32)
    (sz & 0xFFFF_F000) + 0x1000
  end

  lib Data

    struct Header
      # magic number for the header
      magic : UInt32
      # prev header in free list chain
      prev_header : Header*
      # next header in free list chain
      next_header : Header*
      # size of the data next to the header,
      # excluding the size of the footer
      size : UInt32
    end

    struct Footer
      # magic number for the footer
      magic : UInt32
      # corresponding header
      header : Header*
    end

  end

  # alignment
  private def align_up(x)
    x + (0x4 - 1) & -0x4
  end
  private def aligned?(x)
    (x & (0x4 - 1)) == 0
  end

  # minimum size of header + data
  MIN_ALLOC_SIZE = 8
  MIN_ALLOC_DATA = sizeof(Data::Header) + MIN_ALLOC_SIZE + sizeof(Data::Footer)

  # start of the heap
  @heap_start = 0u32
  # end of the heap (must be page aligned)
  @heap_end = 0u32
  # placement address for allocating new headers
  @heap_placement = 0u32
  # first header in free list
  @first_free_header : Data::Header* = Pointer(Data::Header).null

  private def alloc_header(size : UInt32) : Data::Header*
    total_size = sizeof(Data::Header) + size
    units = unit_aligned size
    if @heap_end == 0
      # first allocation
      cur_placement = sbrk(units)
      @heap_start = cur_placement.address.to_u32
      @heap_placement = cur_placement.address.to_u32 + total_size
      @heap_end = cur_placement.address.to_u32 + units
      cur_placement.as(Data::Header*)
    else
      # subsequent allocations with end of heap known
      if @heap_placement + total_size > @heap_end
        # not enough memory in page, allocate another one
        cur_placement = @heap_placement
        sbrk(units)
        @heap_end += units
        @heap_placement += total_size
        Pointer(Data::Header).new(cur_placement.to_u64)
      else
        # enough memory, increase the placement addr and return
        cur_placement = @heap_placement
        @heap_placement += total_size
        Pointer(Data::Header).new(cur_placement.to_u64)
      end
    end
  end

  # chains a header to the free list
  private def chain_header(hdr : Data::Header*)
    hdr.value.next_header = @first_free_header
    if !@first_free_header.null?
      @first_free_header.value.prev_header = hdr
    end
    @first_free_header = hdr
  end

  # unchains a header from the free list
  private def unchain_header(hdr : Data::Header*)
    # dbg "unchain: "; hdr.dbg; dbg "\n"
    if hdr.value.prev_header.null?
      # first in linked list
      if !hdr.value.next_header.null?
        hdr.value.next_header.value.prev_header = Pointer(Data::Header).null
      end
      @first_free_header = hdr.value.next_header
    else
      # middle in linked list
      hdr.value.prev_header.value.next_header = hdr.value.next_header
      if !hdr.value.next_header.null?
        hdr.value.next_header.value.prev_header = hdr.value.prev_header
      end
    end
  end

  # search free list for suitable area
  private def search_free_list(data_sz : UInt32) : Data::Header*
    hdr = @first_free_header
    while !hdr.null?
      # dbg "found size: "; hdr.value.size.dbg; dbg " "; data_sz.dbg; dbg "\n"
      if hdr.value.size >= data_sz
        # found a matching header
        if hdr.value.magic != MAGIC_FREE
          # dbg "non-free header in free list? "; hdr.dbg
          abort
        end
        if (hdr.value.size - data_sz) >= MIN_ALLOC_DATA
          # we can reasonably split this header for more allocation

          # the current layout for the chunk can be seen like this:
          # the region between | and / denotes the user's data
          # [|hdr|---------/---------------|ftr|]
          #                <-  remaining  ->
          new_ftr = Pointer(Data::Footer)
            .new(hdr.address + sizeof(Data::Header) + hdr.value.size)
          if new_ftr.value.magic != FOOTER_MAGIC
            # dbg "invalid magic for footer "; new_ftr.dbg
            abort
          end
          hdr.value.size = data_sz

          # move the old footer
          # [|hdr|---------/|ftr|----------|ftr|]
          ftr = Pointer(Data::Footer).new(hdr.address + sizeof(Data::Header) + data_sz)
          ftr.value.magic = FOOTER_MAGIC
          ftr.value.header = hdr

          # create the header
          # [|hdr|---------/|ftr||hdr|-----|ftr|]
          #                      <-       ->
          new_hdr = Pointer(Data::Header).new(ftr.address + sizeof(Data::Footer))
          new_hdr.value.magic = MAGIC_FREE
          new_hdr.value.size = new_ftr.address - new_hdr.address - sizeof(Data::Header)
          chain_header new_hdr
          new_hdr.value.prev_header = Pointer(Data::Header).null
          new_hdr.value.next_header = Pointer(Data::Header).null

          new_ftr.value.header = new_hdr
        end
        # remove header from list
        unchain_header hdr
        return hdr
      end
      hdr = hdr.value.next_header
    end
    Pointer(Data::Header).null
  end

  def malloc(size : UInt32) : Void*
    if size < MIN_ALLOC_DATA
      size = MIN_ALLOC_DATA.to_u32
    else
      unless aligned?(size)
        size = align_up(size)
      end
    end
    data_size = size
    size += sizeof(Data::Footer)

    if (hdr = search_free_list(data_size)).null?
      hdr = alloc_header size
      hdr.value.size = data_size
    end
    hdr.value.magic = MAGIC
    hdr.value.prev_header = Pointer(Data::Header).null
    hdr.value.next_header = Pointer(Data::Header).null

    ftr = Pointer(Data::Footer).new(hdr.address + sizeof(Data::Header) + hdr.value.size)
    ftr.value.header = hdr
    ftr.value.magic = FOOTER_MAGIC

    (hdr + 1).as(Void*)
  end

  private def footer_before(hdr : Data::Header*)
    Pointer(Data::Footer).new(hdr.address - sizeof(Data::Footer))
  end

  private def header_after(hdr : Data::Header*)
    Pointer(Data::Header)
      .new(hdr.address + sizeof(Data::Header) +
          hdr.value.size + sizeof(Data::Footer))
  end

  def free(ptr : Void*)
    # dbg "FREE "; ptr.dbg; dbg "\n"
    return if ptr.null?

    hdr = Pointer(Data::Header).new(ptr.address - sizeof(Data::Header))
    if hdr.value.magic != MAGIC
      # dbg "free: wrong magic number for hdr"
      abort
    end

    prev_hdr = if hdr.address.to_u32 == @heap_start
                 Pointer(Data::Header).null
               else
                 footer_before(hdr).value.header
               end
    if !prev_hdr.null? &&
        prev_hdr.value.magic != MAGIC && prev_hdr.value.magic != MAGIC_FREE
      # dbg "free: invalid magic number for prev_hdr"
      abort
    end

    next_hdr = header_after(hdr)
    if next_hdr.address.to_u32 >= @heap_placement
      next_hdr = Pointer(Data::Header).null
    end
    if !next_hdr.null? &&
        next_hdr.value.magic != MAGIC && next_hdr.value.magic != MAGIC_FREE
      # dbg "free: invalid magic number for next_hdr\n"
      abort
    end

    # try to coalesce blocks when freeing
    # |hdr|-----|ftr||hdr|----|ftr||hdr|-----|ftr|
    # ^ prev         ^ cur         ^ next    ^
    new_hdr = Pointer(Data::Header).null
    new_ftr = Pointer(Data::Footer).null
    if !prev_hdr.null? && !next_hdr.null? &&
        prev_hdr.value.magic == MAGIC_FREE && next_hdr.value.magic == MAGIC_FREE
      # dbg "case 1\n"
      # case 1: prev is freed and next is freed
      unchain_header next_hdr
      new_hdr = prev_hdr
      new_ftr = Pointer(Data::Footer)
        .new(next_hdr.address + sizeof(Data::Header) + next_hdr.value.size)
      if new_ftr.value.magic != FOOTER_MAGIC
        # dbg "invalid magic for footer "; next_hdr.dbg
        abort
      end

      # resize prev
      new_ftr.value.header = new_hdr
      new_hdr.value.size = new_ftr.address - new_hdr.address - sizeof(Data::Header)
    elsif !prev_hdr.null? && !next_hdr.null? &&
        prev_hdr.value.magic == MAGIC && next_hdr.value.magic == MAGIC_FREE
      # dbg "case 2\n"
      # case 2: prev is allocated and next is freed
      unchain_header next_hdr
      new_hdr = hdr
      new_ftr = Pointer(Data::Footer)
        .new(next_hdr.address + sizeof(Data::Header) + next_hdr.value.size)
      if new_ftr.value.magic != FOOTER_MAGIC
        # dbg "invalid magic for footer "; new_ftr.dbg
        abort
      end

      # resize current
      new_ftr.value.header = new_hdr
      new_hdr.value.size = new_ftr.address - new_hdr.address - sizeof(Data::Header)

      # chain current
      hdr.value.magic = MAGIC_FREE
      chain_header hdr
    elsif !prev_hdr.null? && !next_hdr.null? &&
       prev_hdr.value.magic == MAGIC_FREE && next_hdr.value.magic == MAGIC
      # dbg "case 3\n"
      # case 3: prev is freed and next is allocated
      new_hdr = prev_hdr
      new_ftr = Pointer(Data::Footer)
        .new(hdr.address + sizeof(Data::Header) + hdr.value.size)
      if new_ftr.value.magic != FOOTER_MAGIC
        # dbg "invalid magic for footer "; new_ftr.dbg
        abort
      end

      # resize prev
      new_ftr.value.header = new_hdr
      new_hdr.value.size = new_ftr.address - new_hdr.address - sizeof(Data::Header)
    else
      #dbg "case 4\n"
      # case 4: prev & next are allocated
      hdr.value.magic = MAGIC_FREE
      chain_header hdr
    end

  end

  def realloc(ptr : Void*, size : UInt32) : Void*
    # malloc if null pointer is passed
    if ptr.null?
      return malloc size
    end
    # handle if non-null
    hdr = Pointer(Data::Header).new(ptr.address - sizeof(Data::Header))
    if hdr.value.magic != MAGIC # wrong magic number
      # dbg "invalid pointer"
      abort
    end
    if size == 0
      free ptr
      Pointer(Void).null
    elsif size <= hdr.value.size
      # no need to do anything if it's smaller
      ptr
    else
      # reallocate it
      new_ptr = malloc size
      memcpy new_ptr.as(UInt8*), ptr.as(UInt8*), hdr.value.size
      free ptr
      new_ptr
    end
  end

end

MALLOC = Malloc.new

# c functions
fun calloc(nmeb : UInt32, size : UInt32) : Void*
  ptr = MALLOC.malloc nmeb * size
  memset ptr.as(UInt8*), 0u32, nmeb * size
  ptr
end

fun malloc(size : UInt32) : Void*
  MALLOC.malloc size
end

fun free(ptr : Void*)
  MALLOC.free ptr
end

fun realloc(ptr : Void*, size : UInt32) : Void*
  MALLOC.realloc ptr, size
end