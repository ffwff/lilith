require "./int.cr"
require "./pointer.cr"

lib LibC
  fun strlen(str : LibC::UString) : LibC::Int
  fun strcpy(dest : LibC::UString, src : LibC::UString) : LibC::Int
  fun strncpy(dest : LibC::UString, src : LibC::UString, size : LibC::SizeT) : LibC::Int
  fun strncmp(dest : LibC::UString, src : LibC::UString, size : LibC::SizeT) : LibC::Int
  fun memcmp(s1 : LibC::UString, s2 : LibC::UString, n : LibC::SizeT) : LibC::Int
end

class String
  TYPE_ID     = "".crystal_type_id
  HEADER_SIZE = sizeof({Int32, Int32, Int32})

  class Builder
  end

  def self.new(chars : UInt8*)
    size = LibC.strlen(chars)
    (new(size) { |buffer|
      LibC.strcpy buffer, chars
      {size, String.calculate_length(buffer)}
    }).not_nil!
  end

  def self.new(chars : UInt8*, bytesize, size = 0)
    (new(bytesize) { |buffer|
      LibC.strncpy buffer, chars, bytesize.to_usize
      if size == 0
        size = String.calculate_length buffer
      end
      {bytesize, size}
    }).not_nil!
  end

  def self.new(bytes : Bytes)
    new bytes.to_unsafe
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

  def each_char(&block)
    each_unicode_point do |char|
      yield char
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
    LibC.memcmp(to_unsafe, other.to_unsafe, bytesize) == 0
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

  def split(separator : Char, limit : Int32? = nil, remove_empty = false, &block : String -> _)
    if limit && limit <= 1
      yield self
      return
    end

    last_sep_idx, last_sep_byte_idx = 0, 0
    last_idx, last_byte_idx = 0, 0
    each_unicode_point do |char, idx, byte_idx|
      if char == separator
        if last_sep_idx == 0
          bytesize = byte_idx - 1
          unisize = idx
        else
          bytesize = last_byte_idx - last_sep_byte_idx
          unisize = last_idx - last_sep_idx
        end

        if !remove_empty || (remove_empty && bytesize != 0)
          str = (String.new(bytesize) { |buffer|
            byte_slice[last_sep_byte_idx, bytesize].copy_to buffer, bytesize
            { bytesize, unisize }
          }).not_nil!
          yield str
        end

        last_sep_idx = idx
        last_sep_byte_idx = byte_idx

        if limit
          limit -= 1
          break if limit == 0
        end
      end
      last_idx = idx
      last_byte_idx = byte_idx
    end

    # last substring
    if last_sep_byte_idx == 0
      bytesize = self.bytesize
      unisize = self.size - last_sep_idx
    else
      bytesize = self.bytesize - last_sep_byte_idx
      unisize = self.size - last_sep_idx - 1
    end

    if !remove_empty || (remove_empty && bytesize != 0)
      str = (String.new(bytesize + 1) { |buffer|
        byte_slice[last_sep_byte_idx, bytesize].copy_to buffer, bytesize
        { bytesize, unisize }
      }).not_nil!
      yield str
    end
  end

  def split(separator : Char, limit = nil, remove_empty = false)
    ary = Array(String).new
    split(separator, limit, remove_empty: remove_empty) do |string|
      ary.push string
    end
    ary
  end

  def to_s
    self
  end

  def to_s(io)
    io.write byte_slice
  end

  private INT_BASE = "0123456789abcdefghijklmnopqrstuvwxyz"

  def to_i?(base : Int = 10)
    retval = 0
    self.each_char do |char|
      unless (digit = INT_BASE.index char).nil?
        retval = retval * base + digit
      else
        return nil
      end
    end
    retval
  end

  def to_i(base : Int = 10) : Int32
    if (retval = to_i?(base))
      retval
    else
      0
    end
  end

  def +(other : self) : self
    size = self.bytesize + other.bytesize
    (String.new(size) { |buffer|
      LibC.strcpy buffer, to_unsafe
      LibC.strcpy buffer + self.bytesize, other.to_unsafe
      {size, self.size + other.size}
    }).not_nil!
  end

  def +(other) : self
    self + other.to_s
  end
end
