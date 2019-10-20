lib LibC
  fun memcpy(dest : Void*, src : Void*, n : SizeT) : Void*
end

struct Slice(T)
  getter size

  def initialize(@buffer : Pointer(T), @size : Int32)
  end

  def self.new(size : Int)
    new Pointer(T).malloc_atomic(size), size.to_i32
  end

  def self.empty
    new Pointer(T).null, 0
  end

  def [](idx : Int)
    abort "Slice: out of range" if idx >= @size || idx < 0
    @buffer[idx]
  end

  def []=(idx : Int, value : T)
    abort "Slice: out of range" if idx >= @size || idx < 0
    @buffer[idx] = value
  end

  def [](range : Range(Int, Int))
    abort "Slice: out of range" if range.begin > range.end || range.start + range.end >= @size
    Slice(T).new(@buffer + range.begin, range.size)
  end

  def [](start : Int, count : Int)
    abort "Slice: out of range" if start + count > @size
    Slice(T).new(@buffer + start, count)
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

  def copy_to(target : Pointer(T), count)
    LibC.memcpy(target.as(Void*), to_unsafe.as(Void*), count.to_usize)
  end

  def copy_to(target : self)
    copy_to target.to_unsafe, target.size
  end

  def to_s(io)
    io.print "Slice(", @buffer, " ", @size, ")"
  end
end

alias Bytes = Slice(UInt8)
