struct Slice(T)
  getter size

  def initialize(@buffer : Pointer(T), @size : Int32)
  end

  def [](idx : Int)
    panic "Slice: out of range" if idx > @size || idx < 0
    @buffer[idx]
  end

  def []=(idx : Int, value : T)
    panic "Slice: out of range" if idx > @size || idx < 0
    @buffer[idx] = value
  end

  def each(&block)
    i = 0
    while i < @size
      yield @buffer[i]
      i += 1
    end
  end

  def ==(other)
    return false if other.size != self.size
    i = 0
    other.each do |ch|
      return false if ch != self[i]
      i += 1
    end
    true
  end

  def to_s(io)
    io.puts "Slice(", @buffer, " ", @size, ")"
  end
end
