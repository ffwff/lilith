GC_ARRAY_HEADER_TYPE = 0xFFFF_FFFFu32
GC_ARRAY_HEADER_SIZE =              8

class GcArray(T) < Gc
  GC_GENERIC_TYPES = [
    GcArray(MemMapNode),
    GcArray(FileDescriptor),
    GcArray(AtaDevice),
    GcArray(GcString),
  ]
  # one long for typeid, one long for length
  @size : Int32 = 0
  getter size
  @capacity : Int32 = 0
  getter capacity

  def initialize(@size : Int32)
    malloc_size = @size.to_u32 * sizeof(Void*) + GC_ARRAY_HEADER_SIZE
    @ptr = LibGc.unsafe_malloc(malloc_size).as(UInt32*)
    @ptr[0] = GC_ARRAY_HEADER_TYPE
    @ptr[1] = @size.to_u32
    # clear array
    i = 0
    while i < @size
      buffer.as(UInt8*)[i] = 0u32
      i += 1
    end
    # capacity
    recalculate_capacity
  end

  # helper
  private def buffer
    (@ptr + 2).as(T*)
  end

  private def recalculate_capacity
    @capacity = (KERNEL_ARENA.block_size_for_ptr(@ptr) - GC_ARRAY_HEADER_SIZE) \
      .unsafe_div(sizeof(Void*)).to_i32
  end

  # getter/setter
  def [](idx : Int) : T | Nil
    panic "GcArray: out of range" if idx < 0 && idx > @size
    if buffer.as(UInt32*)[idx] == 0
      nil
    else
      buffer[idx]
    end
  end

  def []=(idx : Int, value : T)
    panic "GcArray: out of range" if idx < 0 && idx > @size
    buffer[idx] = value
  end

  # resizing
  private def new_buffer(@size)
    malloc_size = @size.to_u32 * sizeof(Void*) + GC_ARRAY_HEADER_SIZE
    ptr = LibGc.unsafe_malloc(malloc_size).as(UInt32*)
    ptr[0] = GC_ARRAY_HEADER_TYPE
    ptr[1] = @size
    new_buffer = Pointer(UInt32).new((ptr.address + GC_ARRAY_HEADER_SIZE).to_u64)
    # copy over
    i = 0
    while i < @size
      new_buffer[i] = buffer.as(UInt32*)[i]
      i += 1
    end
    @ptr = ptr
    # capacity
    recalculate_capacity
  end

  def push(value : T)
    if @size < capacity
      buffer[@size] = value
      @size += 1
    else
      panic "gcarray: resize?"
    end
  end

  # iterator
  def each(&block)
    i = 0
    while i < size
      if buffer.as(UInt32*)[i] == 0
        yield nil
      else
        yield buffer[i]
      end
      i += 1
    end
  end
end