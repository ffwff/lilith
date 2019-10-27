class CircularBuffer

  CAPACITY = 0x1000
  @buffer = Pointer(UInt8).null
  @read_pos = 0
  @write_pos = 0

  def init_buffer
    if @buffer.null?
      @buffer = Pointer(UInt8).new(FrameAllocator.claim_with_addr | PTR_IDENTITY_MASK)
    end
  end

  def deinit_buffer
    FrameAllocator.declaim_addr(@buffer.address & ~PTR_IDENTITY_MASK)
  end

  def size
    @write_pos - @read_pos
  end

  def read(slice : Slice(UInt8))
    init_buffer
    slice.size.times do |i|
      slice.to_unsafe[i] = @buffer[@read_pos]
      @read_pos += 1
      if @read_pos == CAPACITY - 1
        @read_pos = 0
      end
      return i if @read_pos == @write_pos
    end
    slice.size
  end

  def write(ch : UInt8)
    @buffer[@write_pos] = ch
    @write_pos += 1
    if @write_pos == CAPACITY - 1
      @write_pos = 0
    end
  end

  def write(slice : Slice(UInt8))
    init_buffer
    slice.size.times do |i|
      @buffer[@write_pos] = slice.to_unsafe[i]
      @write_pos += 1
      if @write_pos == CAPACITY - 1
        @write_pos = 0
      end
      return i if @read_pos == @write_pos
    end
    slice.size
  end

end
