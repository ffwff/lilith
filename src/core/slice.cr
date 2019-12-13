struct Slice(T)
  getter size

  def initialize(@buffer : Pointer(T), @size : Int32)
  end

  def self.null
    new Pointer(T).null, 0
  end

  def null?
    @buffer.null?
  end

  def self.malloc(sz : Int)
    new Pointer(T).malloc(sz.to_u64), sz
  end

  def self.malloc_atomic(sz : Int)
    new Pointer(T).malloc_atomic(sz.to_u64), sz
  end

  def self.mmalloc_a(sz, allocator)
    new allocator.malloc(sz * sizeof(T)).as(T*), sz
  end

  def [](idx : Int)
    panic "Slice: out of range" if idx >= @size || idx < 0
    @buffer[idx]
  end

  def []=(idx : Int, value : T)
    panic "Slice: out of range" if idx >= @size || idx < 0
    @buffer[idx] = value
  end

  def [](range : Range(Int, Int))
    panic "Slice: out of range" if range.begin > range.end
    Slice(T).new(@buffer + range.begin, range.size)
  end

  def to_unsafe
    @buffer
  end

  def each(&block)
    i = 0
    while i < @size
      yield @buffer[i]
      i += 1
    end
  end

  def ==(other : String)
    other == self
  end

  def to_s(io)
    io.print "Slice(", @buffer, " ", @size, ")"
  end
end
