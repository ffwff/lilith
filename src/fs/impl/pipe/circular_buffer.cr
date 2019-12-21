class CircularBuffer
  CAPACITY = 0x1000
  @buffer = Pointer(UInt8).null
  @read_pos = 0
  @write_pos = 0

  def init_buffer
    if @buffer.null?
      @buffer = Pointer(UInt8).new(FrameAllocator.claim_with_addr | Paging::IDENTITY_MASK)
    end
  end

  def deinit_buffer
    FrameAllocator.declaim_addr(@buffer.address & ~Paging::IDENTITY_MASK)
    @buffer = Pointer(UInt8).null
  end

  def size
    (@write_pos - @read_pos).abs
  end

  def read(slice : Slice(UInt8))
    return 0 if @read_pos == @write_pos
    init_buffer
    slice.size.times do |i|
      slice.to_unsafe[i] = @buffer[@read_pos]
      if @read_pos == CAPACITY - 1
        @read_pos = 0
      else
        @read_pos += 1
      end
      if @read_pos == @write_pos
        return i + 1
      end
    end
    slice.size
  end

  def write(ch : UInt8)
    @buffer[@write_pos] = ch
    if @write_pos == CAPACITY - 1
      @write_pos = 0
    else
      @write_pos += 1
    end
  end

  def write(slice : Slice(UInt8))
    init_buffer
    slice.size.times do |i|
      write(slice.to_unsafe[i])
    end
    slice.size
  end
end
