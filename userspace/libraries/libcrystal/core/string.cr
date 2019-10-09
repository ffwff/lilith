require "./int.cr"
require "./pointer.cr"

class String
  def size
    @length
  end

  def bytesize
    @bytesize
  end

  def to_unsafe : UInt8*
    pointerof(@c)
  end

  def each
    size.times do |i|
      yield bytes[i], i
    end
  end

  def to_s
    self
  end

  def to_s(io)
    each do |char|
      io.putc char
    end
  end

  def [](index : Int)
    bytes[index]
  end
  
  def ===(other)
    self == other
  end

end
