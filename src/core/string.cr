require "./int.cr"
require "./pointer.cr"

class String
  TYPE_ID     = "".crystal_type_id
  HEADER_SIZE = sizeof({Int32, Int32, Int32})

  class Builder
    def initialize(@capacity : Int32)
      @buffer = Pointer(UInt8).malloc_atomic(@capacity.to_u32 + HEADER_SIZE + 1)
      @bytesize = 0
      @finished = false
    end

    def buffer
      @buffer + String::HEADER_SIZE
    end

    def write_byte(other : UInt8)
      if @bytesize == @capacity
        panic "resizing string unimplemented!"
      end
      buffer[@bytesize] = other
      @bytesize += 1
    end

    def <<(other : String)
      other.each_byte do |byte|
        write_byte byte
      end
    end

    def to_s : String
      panic "Can only invoke 'to_s' once on String::Builder" if @finished
      @finished = true

      write_byte 0u8

      header = @buffer.as({Int32, Int32, Int32}*)
      header.value = {String::TYPE_ID, @bytesize - 1, String.calculate_length(buffer)}
      @buffer.as(String)
    end

    def reset(capacity : Int)
      panic "TODO"
    end
  end

  def self.new(capacity : Int)
    str = Pointer(UInt8).malloc_atomic(capacity.to_u32 + HEADER_SIZE + 1)
    buffer = str.as(String).to_unsafe
    bytesize, size = yield buffer

    unless 0 <= bytesize <= capacity
      return nil
    end

    buffer[bytesize] = 0_u8

    # TODO: Try to reclaim some memory if capacity is bigger than what was requested

    str_header = str.as({Int32, Int32, Int32}*)
    str_header.value = {TYPE_ID, bytesize.to_i, size.to_i}
    str.as(String)
  end

  def self.new(bytes : Slice(UInt8))
    panic "TODO"
  end

  def self.new(bytes : NullTerminatedSlice)
    panic "TODO"
  end

  protected def self.calculate_length(buffer : UInt8*)
    i = 0
    length = 0
    until (ch = buffer[i]) == 0u8
      if ch >= 0b110_00000u8
        i += 2
      elsif ch >= 0b1110_0000u8
        i += 3
      elsif ch >= 0b11110_000u8
        i += 4
      else
        i += 1
      end
      length += 1
    end
    length
  end

  private def mask_tail_char(ch : UInt8) : UInt32
    (ch & 0b111111u8).to_u32
  end

  private def each_unicode_point
    i = 0
    points = 0
    until (ch = to_unsafe[i]) == 0u8
      point = 0u32
      if ch >= 0b110_00000u8
        point = (ch & 0b11111u8).to_u32 << 6 | mask_tail_char(to_unsafe[i + 1])
        i += 2
      elsif ch >= 0b1110_0000u8
        point = (ch & 0b1111u8).to_u32 << 12 |
                (mask_tail_char(to_unsafe[i + 1]) << 6) |
                (mask_tail_char(to_unsafe[i + 2]))
        i += 3
      elsif ch >= 0b11110_000u8
        point = (ch & 0b1111u8).to_u32 << 18 |
                (mask_tail_char(to_unsafe[i + 1]) << 12) |
                (mask_tail_char(to_unsafe[i + 2]) << 6) |
                (mask_tail_char(to_unsafe[i + 3]))
        i += 4
      else
        point = ch.to_u32
        i += 1
      end
      yield point.unsafe_chr, points, i
      points += 1
    end
  end

  def clone
    panic "TODO"
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
    Slice(UInt8).new(to_unsafe, bytesize)
  end

  def each_char(&block)
    each_unicode_point do |char|
      yield char
    end
  end

  def each_byte(&block)
    @bytesize.times do |i|
      yield to_unsafe[i]
    end
  end

  def [](index : Int)
    each_unicode_point do |char, i|
      return char if i == index
    end
    0.unsafe_chr
  end

  def ==(other : self)
    return true if same?(other)
    return false unless bytesize == other.bytesize
    memcmp(to_unsafe, other.to_unsafe, bytesize) == 0
  end

  def ==(other : Slice(UInt8))
    panic "TODO"
  end

  def ===(other)
    self == other
  end

  def index(search)
    each_unicode_point do |char, i|
      return i if search == char
    end
    nil
  end

  def to_s
    self
  end

  def to_s(io)
    each_byte do |char|
      io.putc char
    end
  end

end
