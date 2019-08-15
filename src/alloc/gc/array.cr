GC_ARRAY_HEADER_TYPE = 0xFFFF_FFFF_FFFF_FFFFu64  
GC_ARRAY_HEADER_SIZE = sizeof(USize) * 2

class GcArray(T)

  @capacity : Int64 = 0
  getter capacity
  
  # array data is stored in buffer, and so is size
  def size
    @ptr[1].to_isize
  end

  private def size=(new_size)
    @ptr[1] = new_size.to_usize
  end

  private def malloc_size(new_size)
    new_size.to_usize * sizeof(Void*) + GC_ARRAY_HEADER_SIZE
  end

  # init
  def initialize(new_size : Int)
    m_size = malloc_size new_size
    @ptr = Gc.unsafe_malloc(m_size).as(USize*)
    @ptr[0] = GC_ARRAY_HEADER_TYPE
    @ptr[1] = new_size.to_usize
    # clear array
    i = 0
    while i < new_size
      buffer.as(USize*)[i] = 0u64
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
    @capacity = (KernelArena.block_size_for_ptr(@ptr) -
      (GC_ARRAY_HEADER_SIZE + sizeof(Kernel::GcNode)))
      .unsafe_div(sizeof(Void*)).to_isize
  end

  # getter/setter
  def [](idx : Int) : T?
    panic "GcArray: out of range" if idx < 0 && idx >= size
    if buffer.as(USize*)[idx] == 0
      nil
    else
      buffer[idx]
    end
  end

  def []=(idx : Int, value : T)
    panic "GcArray: out of range" if idx < 0 && idx >= size
    buffer[idx] = value
  end

  def []=(idx : Int, value : Nil)
    panic "GcArray: out of range" if idx < 0 && idx >= size
    buffer.as(USize*)[idx] = 0
  end

  # resizing
  private def new_buffer(new_size)
    m_size = malloc_size new_size
    ptr = Gc.unsafe_malloc(m_size).as(USize*)
    ptr[0] = GC_ARRAY_HEADER_TYPE
    ptr[1] = new_size.to_usize
    new_buffer = Pointer(USize).new((ptr.address + GC_ARRAY_HEADER_SIZE).to_u64)
    # copy over
    i = 0
    while i < new_size
      new_buffer[i] = buffer.as(USize*)[i]
      i += 1
    end
    @ptr = ptr
    # capacity
    recalculate_capacity
  end

  def push(value : T)
    if size < capacity
      buffer[size] = value
      self.size += 1
    else
      new_buffer(size + 1)
      buffer[size] = value
      self.size += 1
    end
  end

  # iterator
  def each(&block)
    i = 0
    while i < size
      if buffer.as(USize*)[i] == 0
        yield nil
      else
        yield buffer[i]
      end
      i += 1
    end
  end
end