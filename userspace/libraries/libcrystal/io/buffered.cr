module IO::Buffered
  @buffer = Bytes.empty
  @buffer_size = 512
  @pos = 0

  # Reads at most *slice.size* bytes from the wrapped `IO` into *slice*.
  # Returns the number of bytes read.
  abstract def unbuffered_read(slice : Bytes)

  # Writes at most *slice.size* bytes from *slice* into the wrapped `IO`.
  # Returns the number of bytes written.
  abstract def unbuffered_write(slice : Bytes)

  def buffer_size
    @buffer_size
  end

  def buffer_size=(value)
    if @buffer.size < 0
      @buffer_size = value
    end
  end

  private def lazy_init
    if @buffer.size == 0
      @buffer = Bytes.new @buffer_size
    end
  end

  def read(slice : Bytes)
    # TODO
    unbuffered_read slice
  end

  def write(slice : Bytes)
    if @buffer_size == 0
      return unbuffered_write(slice)
    end

    lazy_init
    slice.each do |ch|
      @buffer[@pos] = ch
      @pos += 1
      if @pos == @buffer.size
        flush
      end
    end
  end

  def flush
    if @pos > 0
      unbuffered_write(@buffer[0, @pos])
    end
    @pos = 0
  end
end
