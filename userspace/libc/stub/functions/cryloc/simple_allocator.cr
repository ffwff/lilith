{% if !flag?(:cryloc_lock) %}
struct Cryloc::Lock
  def self.init?
    0i32
  end

  def self.init
  end

  def self.enter
  end

  def self.leave
  end
end
{% end %}

# A Simple allocator using a linked free list
# This implementation is easily portable as it only needs a sbrk(2) implementation.
struct Cryloc::SimpleAllocator
  ALIGN               = 8u64
  PTR_SIZE            = sizeof(Pointer(Void))
  CHUNK_SIZE          = sizeof(Chunk)
  MIN_ALLOC_SIZE      = PTR_SIZE
  PADDING             = cryloc_max(ALIGN, PTR_SIZE) - PTR_SIZE
  SMALLEST_CHUNK_SIZE = CHUNK_SIZE + PADDING + MIN_ALLOC_SIZE
  MAX_ALLOC_SIZE      = 0x80000000

  SBRK_ERROR_CODE = 0xFFFFFFFF

  @@heap_start : Void* = Pointer(Void).new(0)
  @@free_list : Chunk* = Pointer(Chunk).new(0)

  struct Chunk
    @size : Int64 = 0
    @next_chunk : Chunk* = Pointer(Chunk).new(0)

    def size
      @size
    end

    def size=(size : Int64)
      @size = size
    end

    def next_chunk
      @next_chunk
    end

    def next_chunk=(next_chunk : Chunk*)
      @next_chunk = next_chunk
    end

    def self.from_data_ptr(ptr : Void*) : Chunk*
      chunk_ptr = ptr.address - CHUNK_SIZE
      res = Pointer(Chunk).new(chunk_ptr)

      if res.value.size < 0
        # The chunk size is negative so this is a padding chunk.
        # The actual chunk position is at size.
        res = Pointer(Chunk).new(chunk_ptr + res.value.size)
      end
      res
    end
  end

  private def self.lock
    if !Lock.init?
      Lock.init
    end
    Lock.enter
  end

  private def self.unlock
    if !Lock.init?
      Lock.init
    end
    Lock.leave
  end

  private def self.reserve_memory(size : SizeT) : Void*
    # init heap_start if needed
    if @@heap_start.address == 0
      @@heap_start = sbrk(0)
    end

    # ask for the size
    ptr = sbrk(size)
    if (ptr.address == SBRK_ERROR_CODE)
      return Pointer(Void).new(0)
    end

    # align and ask more size if needed
    aligned_size = cryloc_align(size, PTR_SIZE)
    if aligned_size != size
      ptr = sbrk(aligned_size)
      if (ptr.address == SBRK_ERROR_CODE)
        return Pointer(Void).new(0)
      end
      return ptr
    end
    ptr
  end

  def self.allocate(size : SizeT) : Void*
    # first we determine the real size needed to allocate the element.
    # align size
    allocation_size = cryloc_align(size, ALIGN)

    # extra padding to ensure we follow ALIGN requirements.
    allocation_size += PADDING

    allocation_size += CHUNK_SIZE

    allocation_size = cryloc_max(allocation_size, SMALLEST_CHUNK_SIZE.to_ssize)

    if allocation_size >= MAX_ALLOC_SIZE || allocation_size < size
      # TODO: errno?
      return Pointer(Void).new(0)
    end

    lock()

    previous_chunk = @@free_list
    res_chunk = @@free_list

    until res_chunk.address == 0
      remaining = res_chunk.value.size - allocation_size
      if remaining > 0
        if remaining >= SMALLEST_CHUNK_SIZE
          # found a chunk that is big enough to store another chunk, split it in two and return the second one
          res_chunk.value.size = remaining

          res_chunk = Pointer(Chunk).new(res_chunk.address + remaining)

          # NOTE: might look a dangerous conversion BUT we check before that we don't exceed Int32::MAX so it's fine
          res_chunk.value.size = allocation_size.to_i64
        elsif previous_chunk.address == res_chunk.address
          @@free_list = res_chunk.value.next_chunk
        else
          # normal case, remove from the free list
          previous_chunk.value.next_chunk = res_chunk.value.next_chunk
        end
        break
      end
      previous_chunk = res_chunk
      res_chunk = res_chunk.value.next_chunk
    end

    # failed to find a chunk?
    if res_chunk.address == 0
      res_chunk = reserve_memory(allocation_size).as(Chunk*)
      if res_chunk.address == 0
        # TODO: errno?
        unlock()
        return Pointer(Void).new(0)
      end
      res_chunk.value.size = allocation_size.to_i64
      res_chunk.value.next_chunk = Pointer(Chunk).new(0)
    end

    unlock()
    ptr = res_chunk.address + CHUNK_SIZE
    aligned_ptr = cryloc_align(ptr, ALIGN)

    padding = aligned_ptr - ptr
    if padding != 0
      tmp = Pointer(Int64).new(res_chunk.address + padding)
      tmp.value = 0i64 - padding
    end

    Pointer(Void).new(aligned_ptr)
  end

  def self.release(ptr : Void*)
    if ptr.address == 0
      return
    end

    chunk_to_free = Chunk.from_data_ptr(ptr)

    lock()
    # print_free_list()

    if @@free_list.address == 0
      chunk_to_free.value.next_chunk = @@free_list
      @@free_list = chunk_to_free
      unlock()
      return
    end

    # before free_list address?
    if chunk_to_free.address < @@free_list.address
      if (chunk_to_free.address + chunk_to_free.value.size) == @@free_list.address
        # this chunk is right before the first free chunk, merge them into one.
        chunk_to_free.value.size = chunk_to_free.value.size + @@free_list.value.size
        chunk_to_free.value.next_chunk = @@free_list.value.next_chunk
      else
        chunk_to_free.value.next_chunk = @@free_list
      end

      @@free_list = chunk_to_free
      unlock()
      return
    end

    # we try to find the chunk that have an address right before chunk_to_free.
    before_free_chunk = Pointer(Chunk).new(0)
    after_free_chunk = @@free_list
    unless after_free_chunk.address == 0 || after_free_chunk.address > chunk_to_free.address
      before_free_chunk = after_free_chunk
      after_free_chunk = after_free_chunk.value.next_chunk
    end

    # right before chunk_to_free?
    if (before_free_chunk.address + before_free_chunk.value.size) == chunk_to_free.address
      # merge the two chunks
      before_free_chunk.value.size = chunk_to_free.value.size + before_free_chunk.value.size

      # if this new sized chunk is alos right before after_free_chunk
      if (before_free_chunk.address + before_free_chunk.value.size) == after_free_chunk.address
        # merge the two chunks and update next pointer
        before_free_chunk.value.size = before_free_chunk.value.size + after_free_chunk.value.size
        before_free_chunk.value.next_chunk = after_free_chunk.value.next_chunk
      end
    elsif (before_free_chunk.address + before_free_chunk.value.size) > chunk_to_free.address
      # FIXME: double free fault
      # TODO: errno?
      unlock()
      return
    elsif (chunk_to_free.address + chunk_to_free.value.size) == after_free_chunk.address
      # adjacent to a free chunk so we merge the two chunks.
      chunk_to_free.value.size = chunk_to_free.value.size + after_free_chunk.value.size
      chunk_to_free.value.next_chunk = after_free_chunk.value.next_chunk
      before_free_chunk.value.next_chunk = chunk_to_free
    else
      # no adjacent chunk found... this cause a fragmentation.
      chunk_to_free.value.next_chunk = after_free_chunk
      before_free_chunk.value.next_chunk = chunk_to_free
    end
    # print_free_list()
    unlock()
  end

  def self.re_allocate(ptr : Void*, size : SizeT) : Void*
    if (ptr.address == 0)
      return allocate(size)
    elsif size == 0
      release(ptr)
      return Pointer(Void).new(0)
    end

    usable_size = (Chunk.from_data_ptr(ptr).value.size - CHUNK_SIZE)
    # if the chunk has enough memory to hold the size, return it.
    if (usable_size >= size)
      return ptr
    end

    # otherwise, reallocate.
    new_ptr = allocate(size)
    unless new_ptr.address == 0
      cryloc_memcpy(new_ptr.as(UInt8*), ptr.as(UInt8*), usable_size.to_u64)
      release(ptr)
    end
    new_ptr
  end

  def self.allocate_aligned(alignment : SizeT, size : SizeT) : Void*
    if (alignment & (alignment - 1)) != 0
      return Pointer(Void).new(0)
    end

    alignment += cryloc_max(alignment, PADDING)

    # prepare a size that may be bigger than the one asked, but we will truncate that after.
    memory_align_size = cryloc_align(cryloc_max(size, MIN_ALLOC_SIZE), CHUNK_SIZE)
    padded_size = (memory_align_size + alignment - PADDING).to_ssize

    ptr = allocate(padded_size)
    if (ptr.address == 0)
      return ptr
    end

    chunk = Chunk.from_data_ptr(ptr)
    aligned_ptr = cryloc_align(chunk.address + CHUNK_SIZE, alignment)
    padding = aligned_ptr - (chunk.address + CHUNK_SIZE)

    if padding != 0
      if padding >= MIN_ALLOC_SIZE
        # the padding before is way too big, free it.

        # save the old pointer
        tmp_chunk = chunk
        # create the real padded chunk
        chunk = Pointer(Chunk).new(chunk.address + padding)
        chunk.value.size = tmp_chunk.value.size - padding

        # update size of the old chunk with the padding
        tmp_chunk.value.size = padding.to_i64

        # add the chunk to the free list
        release(Pointer(Void).new(tmp_chunk.address + CHUNK_SIZE))
      else
        # set a padding chunk for the aligned chunk
        tmp = Pointer(Int64).new(chunk.address + padding)
        tmp.value = 0i64 - padding
      end
    end

    allocated_size = chunk.value.size

    if chunk.address + allocated_size > aligned_ptr + memory_align_size + MIN_ALLOC_SIZE
      # the padding after is way too big, free it.
      # redure the padded chunk size and create a new chunk that will be added to the free list.
      tmp_chunk = Pointer(Chunk).new(aligned_ptr + memory_align_size)
      chunk.value.size = (aligned_ptr + memory_align_size - chunk.address).to_i64
      tmp_chunk.value.size = allocated_size - chunk.value.size
      release(Pointer(Void).new(tmp_chunk.address + CHUNK_SIZE))
    end

    Pointer(Void).new(aligned_ptr)
  end
end
