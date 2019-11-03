# simple free-list based memory allocator
# reference: https://moss.cs.iit.edu/cs351/slides/slides-malloc.pdf
module Malloc
  extend self

  MAGIC        = 0x1badc0fe
  MAGIC_FREE   = 0x2badc0fe
  FOOTER_MAGIC = 0x1badb011
  ALLOC_UNIT   =  0x1000u32

  def unit_aligned(sz)
    (sz & 0xFFFF_F000) + 0x1000
  end

  lib Data
    struct Header
      # magic number for the header
      magic : LibC::SizeT
      # prev header in free list chain
      prev_header : Header*
      # next header in free list chain
      next_header : Header*
      # size of the data next to the header,
      # excluding the size of the footer
      size : LibC::SizeT
    end

    struct Footer
      # magic number for the footer
      magic : LibC::SizeT
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
  @@heap_start : LibC::SizeT = 0.to_usize
  # end of the heap (must be page aligned)
  @@heap_end : LibC::SizeT = 0.to_usize
  # placement address for allocating new headers
  @@heap_placement : LibC::SizeT = 0.to_usize
  # first header in free list
  @@first_free_header : Data::Header* = Pointer(Data::Header).null

  def heap_start
    @@heap_start
  end

  def heap_placement
    @@heap_placement
  end

  private def alloc_header(size : LibC::SizeT) : Data::Header*
    total_size = sizeof(Data::Header) + size
    units = unit_aligned size
    if @@heap_end == 0
      # first allocation
      cur_placement = sbrk(units)
      @@heap_start = cur_placement.address.to_usize
      @@heap_placement = cur_placement.address.to_usize + total_size
      @@heap_end = cur_placement.address.to_usize + units
      cur_placement.as(Data::Header*)
    else
      # subsequent allocations with end of heap known
      if @@heap_placement + total_size > @@heap_end
        # not enough memory in page, allocate another one
        cur_placement = @@heap_placement
        sbrk(units)
        @@heap_end += units
        @@heap_placement += total_size
        Pointer(Data::Header).new(cur_placement.to_u64)
      else
        # enough memory, increase the placement addr and return
        cur_placement = @@heap_placement
        @@heap_placement += total_size
        Pointer(Data::Header).new(cur_placement.to_u64)
      end
    end
  end

  # chains a header to the free list
  private def chain_header(hdr : Data::Header*)
    hdr.value.next_header = @@first_free_header
    unless @@first_free_header.null?
      @@first_free_header.value.prev_header = hdr
    end
    @@first_free_header = hdr
  end

  # unchains a header from the free list
  private def unchain_header(hdr : Data::Header*)
    if hdr == @@first_free_header
      @@first_free_header = hdr.value.next_header
    end
    unless hdr.value.next_header.null?
      # hdr->next->prev = hdr->prev
      hdr.value.next_header.value.prev_header = hdr.value.prev_header
    end
    unless hdr.value.prev_header.null?
      # hdr->prev->next = hdr->next
      hdr.value.prev_header.value.next_header = hdr.value.next_header
    end
    hdr.value.prev_header = Pointer(Data::Header).null
    hdr.value.next_header = Pointer(Data::Header).null
  end

  # search free list for suitable area
  private def search_free_list(data_sz : LibC::SizeT) : Data::Header*
    hdr = @@first_free_header
    while !hdr.null?
      # dbg "found size: "; hdr.value.size.dbg; dbg " "; data_sz.dbg; dbg "\n"
      if hdr.value.size >= data_sz
        # found a matching header
        if hdr.value.magic != MAGIC_FREE
          # dbg "non-free header in free list? "; hdr.dbg
          abort
        end
        split_block hdr, data_sz
        # remove header from list
        unchain_header hdr
        return hdr
      end
      hdr = hdr.value.next_header
    end
    Pointer(Data::Header).null
  end

  # split the block
  private def split_block(hdr : Data::Header*, data_sz : LibC::SizeT)
    if (hdr.value.size - data_sz) >= MIN_ALLOC_DATA
      # we can reasonably split this header for more allocation

      # the current layout for the chunk can be seen like this:
      # the region between | and / denotes the user's data
      # [|hdr|---------/---------------|ftr|]
      #                <-  remaining  ->
      new_ftr = footer_for_block(hdr)
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
  end

  def malloc(size : LibC::SizeT) : Void*
    if size < MIN_ALLOC_DATA
      size = MIN_ALLOC_DATA.to_usize
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
      hdr.value.prev_header = Pointer(Data::Header).null
      hdr.value.next_header = Pointer(Data::Header).null
    end
    hdr.value.magic = MAGIC

    ftr = Pointer(Data::Footer).new(hdr.address + sizeof(Data::Header) + hdr.value.size)
    ftr.value.header = hdr
    ftr.value.magic = FOOTER_MAGIC

    (hdr + 1).as(Void*)
  end

  private def footer_before(hdr : Data::Header*)
    Pointer(Data::Footer).new(hdr.address - sizeof(Data::Footer))
  end

  private def footer_for_block(hdr)
    ftr = Pointer(Data::Footer).new(hdr.address + sizeof(Data::Header) + hdr.value.size)
    if ftr.value.magic != FOOTER_MAGIC
      Stdio.stderr.fputs "free: invalid magic number for ftr"
      abort
    end
    ftr
  end

  private def header_after(hdr : Data::Header*)
    Pointer(Data::Header)
      .new(hdr.address + sizeof(Data::Header) +
           hdr.value.size + sizeof(Data::Footer))
  end

  private def prev_block_hdr(hdr : Data::Header*)
    prev_hdr = if hdr.address.to_u32 == @@heap_start
                 Pointer(Data::Header).null
               else
                 footer_before(hdr).value.header
               end
    if !prev_hdr.null? &&
       prev_hdr.value.magic != MAGIC && prev_hdr.value.magic != MAGIC_FREE
      Stdio.stderr.fputs "free: invalid magic number for prev_hdr"
      abort
    end
    prev_hdr
  end

  private def next_block_hdr(hdr : Data::Header*)
    next_hdr = header_after(hdr)
    if next_hdr.address.to_u32 >= @@heap_placement
      next_hdr = Pointer(Data::Header).null
    end
    if !next_hdr.null? &&
       next_hdr.value.magic != MAGIC && next_hdr.value.magic != MAGIC_FREE
      Stdio.stderr.fputs "free: invalid magic number for next_hdr\n"
      abort
    end
    next_hdr
  end

  def free(ptr : Void*)
    # dbg "FREE "; ptr.dbg; dbg "\n"
    return if ptr.null?

    hdr = Pointer(Data::Header).new(ptr.address - sizeof(Data::Header))
    if hdr.value.magic != MAGIC
      Stdio.stderr.fputs "free: wrong magic number for hdr\n"
      abort
    end

    prev_hdr, next_hdr = prev_block_hdr(hdr), next_block_hdr(hdr)

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
      new_ftr = footer_for_block(next_hdr)

      # resize prev
      new_ftr.value.header = new_hdr
      new_hdr.value.size = new_ftr.address - new_hdr.address - sizeof(Data::Header)
    elsif !prev_hdr.null? && !next_hdr.null? &&
          prev_hdr.value.magic == MAGIC && next_hdr.value.magic == MAGIC_FREE
      # dbg "case 2\n"
      # case 2: prev is allocated and next is freed
      unchain_header next_hdr
      new_hdr = hdr
      new_ftr = footer_for_block(next_hdr)

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
      new_ftr = footer_for_block(hdr)

      # resize prev
      new_ftr.value.header = new_hdr
      new_hdr.value.size = new_ftr.address - new_hdr.address - sizeof(Data::Header)
    else
      # dbg "case 4\n"
      # case 4: prev & next are allocated
      hdr.value.magic = MAGIC_FREE
      chain_header hdr
    end
  end

  def realloc(ptr : Void*, size : LibC::SizeT) : Void*
    # malloc if null pointer is passed
    if ptr.null?
      return malloc size
    end
    # handle if non-null
    hdr = Pointer(Data::Header).new(ptr.address - sizeof(Data::Header))
    if hdr.value.magic != MAGIC # wrong magic number
      Stdio.stderr.fputs "free: invalid pointer"
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
      old_size = hdr.value.size

      prev_hdr, next_hdr = prev_block_hdr(hdr), next_block_hdr(hdr)
      new_hdr = Pointer(Data::Header).null
      new_ftr = Pointer(Data::Header).null

      # |hdr|-----|ftr||hdr|----|ftr||hdr|-----|ftr|
      # ^ prev         ^ cur         ^ next    ^
      if !prev_hdr.null? && !next_hdr.null? &&
         prev_hdr.value.magic == MAGIC && next_hdr.value.magic == MAGIC_FREE
        # prioritise this case first because we wouldn't need to move memory
        # case 2: prev is allocated and next is freed
        new_size = footer_for_block(next_hdr).address - hdr.address - sizeof(Data::Header)
        if new_size >= size
          unchain_header next_hdr

          new_hdr = hdr
          new_ftr = footer_for_block(next_hdr)

          new_hdr.value.magic = MAGIC
          new_hdr.value.size = new_size

          new_ftr.value.header = new_hdr
          return ptr
        end
      elsif !prev_hdr.null? && !next_hdr.null? &&
            prev_hdr.value.magic == MAGIC_FREE && next_hdr.value.magic == MAGIC_FREE
        # case 1: prev & next are freed
        new_size = footer_for_block(next_hdr).address - prev_hdr.address - sizeof(Data::Header)
        if new_size >= size
          unchain_header prev_hdr
          unchain_header next_hdr

          new_hdr = prev_hdr
          new_ftr = footer_for_block(next_hdr)

          new_hdr.value.magic = MAGIC
          new_hdr.value.size = new_size

          new_ftr.value.header = new_hdr
        end
      elsif !prev_hdr.null? && !next_hdr.null? &&
            prev_hdr.value.magic == MAGIC_FREE && next_hdr.value.magic == MAGIC
        # case 1: prev is freed and next is allocated
        new_size = footer_for_block(hdr).address - prev_hdr.address - sizeof(Data::Header)
        if new_size >= size
          unchain_header prev_hdr

          new_hdr = prev_hdr
          new_ftr = footer_for_block(hdr)

          new_hdr.value.magic = MAGIC
          new_hdr.value.size = new_size

          new_ftr.value.header = new_hdr
        end
      end

      if !new_hdr.null? && !new_ftr.null?
        # move data over
        new_ptr = Pointer(Void).new(new_hdr.address + sizeof(Data::Header))
        memmove new_ptr.as(UInt8*), ptr.as(UInt8*), old_size

        # split the block
        split_block new_hdr, size
        return new_ptr
      end

      new_ptr = malloc size
      memcpy new_ptr.as(UInt8*), ptr.as(UInt8*), old_size
      free ptr
      new_ptr
    end
  end
end

# c functions
  fun calloc(nmemb : LibC::SizeT, size : LibC::SizeT) : Void*
  ptr = Malloc.malloc nmemb * size
  memset ptr.as(UInt8*), 0u32, nmemb * size
  ptr
end

fun malloc(size : LibC::SizeT) : Void*
  Malloc.malloc size
end

fun free(ptr : Void*)
  Malloc.free ptr
end

fun realloc(ptr : Void*, size : LibC::SizeT) : Void*
  Malloc.realloc ptr, size
end

fun __libc_heap_start : Void*
  Pointer(Void).new Malloc.heap_start.to_u64
end

fun __libc_heap_placement : Void*
  Pointer(Void).new Malloc.heap_placement.to_u64
end
