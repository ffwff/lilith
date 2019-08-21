# TODO: replace with String

class GcString
  getter size
  @capacity : Int32 = 0
  getter capacity

  def initialize(buffer, @size : Int32)
    @capacity = @size.nearest_power_of_2
    @buffer = Pointer(UInt8).malloc(@capacity.to_u32)
    @size.times do |i|
      @buffer[i] = buffer[i]
    end
  end

  def initialize(@size : Int32)
    @capacity = @size.nearest_power_of_2
    @buffer = Pointer(UInt8).malloc(@capacity.to_u32)
    @size.times do |i|
      @buffer[i] = 0u8
    end
  end

  def initialize(buffer)
    @size = buffer.size
    @capacity = @size.nearest_power_of_2
    @buffer = Pointer(UInt8).malloc(@capacity.to_u32)
    @size.times do |i|
      @buffer[i] = buffer[i]
    end
  end

  # methods
  def []=(k : Int, value : UInt8)
    panic "cstring: out of range" if k > size || k < 0
    @buffer[k] = value
  end

  def [](k : Int) : UInt8
    panic "cstring: out of range" if k > size || k < 0
    @buffer[k]
  end

  def [](range : Range(Int, Int))
    panic "cstring: out of range" if range.begin > range.end
    Slice(UInt8).new(@buffer + range.begin, range.size)
  end

  def ==(other)
    return false if size != other.size
    @size.times do |i|
      return false if @buffer[i] != other[i]
    end
    true
  end

  #
  def each(&block)
    @size.times do |i|
      yield @buffer[i]
    end
  end

  def to_s(io)
    each do |ch|
      io.puts ch.unsafe_chr
    end
  end

  #
  private def expand
    @capacity *= 2
    old_buffer = @buffer
    @buffer = Pointer(UInt8).malloc(@capacity)
    memcpy(@buffer, old_buffer, @size.to_usize)
  end

  def resize(size : Int32)
    if size > @capacity
      panic "GcString : @size must be < @capacity"
    end
    @size = size
  end

  def insert(idx : Int32, ch : UInt8)
    if idx == @size
      if @size == @capacity
        expand
      end
      @size += 1
    end
    @buffer[idx] = ch
  end

  def <<(ch : UInt8)
    insert @size, ch
  end

  @[NoInline]
  def <<(str)
    str.each do |ch|
      insert @size, ch
    end
  end

  # cloning
  def clone
    GcString.new(@buffer, @size)
  end
end
