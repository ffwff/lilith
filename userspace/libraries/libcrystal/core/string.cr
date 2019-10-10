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

  def byte_slice
    Bytes.new(to_unsafe, bytesize)
  end

  def each
    size.times do |i|
      yield to_unsafe[i], i
    end
  end

  def to_s
    self
  end

  def to_s(io)
    io.write byte_slice
  end

  def [](index : Int)
    bytes[index]
  end
  
  def ===(other)
    self == other
  end

end
