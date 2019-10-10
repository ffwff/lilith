require "./int.cr"
require "./pointer.cr"

lib LibC
  fun strlen(str : LibC::UString) : LibC::Int
  fun strcpy(dest : LibC::UString, src : LibC::UString) : LibC::Int
end

class String
  TYPE_ID = "".crystal_type_id
  HEADER_SIZE = sizeof({Int32, Int32, Int32})

  class Builder
  end

  def self.new(chars : UInt8*)
    size = LibC.strlen(chars)
    new(size) do |buffer|
      LibC.strcpy buffer, chars
      Tuple.new(size, size)
    end
  end

  def self.new(capacity : Int)
    # str = GC.malloc_atomic(capacity.to_u32 + HEADER_SIZE + 1).as(UInt8*)
    str = Pointer(UInt8).malloc(capacity.to_u32 + HEADER_SIZE + 1)
    buffer = str.as(String).to_unsafe
    bytesize, size = yield buffer

    unless 0 <= bytesize <= capacity
      unimplemented!
      # raise ArgumentError.new("Bytesize out of capacity bounds")
    end

    buffer[bytesize] = 0_u8

    # Try to reclaim some memory if capacity is bigger than what was requested
    if bytesize < capacity
      # TODO
      # str = str.realloc(bytesize.to_u32 + HEADER_SIZE + 1)
    end

    str_header = str.as({Int32, Int32, Int32}*)
    str_header.value = {TYPE_ID, bytesize.to_i, size.to_i}
    str.as(String)
  end

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
