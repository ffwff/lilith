require "./int.cr"
require "./pointer.cr"

class String
  TYPE_ID     = "".crystal_type_id
  HEADER_SIZE = sizeof({Int32, Int32, Int32})

  class Builder
    @capacity : Int32 = 0
    @bytesize : Int32 = 0
    getter capacity, bytesize

    def initialize(capacity : Int32)
      @buffer = Pointer(UInt8).malloc_atomic(capacity.to_u32 + 1 + HEADER_SIZE)
      @capacity = capacity_for_ptr @buffer
      @bytesize = 0
      @finished = false
    end

    def initialize
      @capacity = 0
      @buffer = Pointer(UInt8).null
      @bytesize = 0
      @finished = false
    end

    private def capacity_for_ptr(ptr)
      (Allocator.block_size_for_ptr(ptr) - HEADER_SIZE).to_i32
    end

    def buffer
      @buffer + String::HEADER_SIZE
    end

    def empty?
      @bytesize == 0
    end

    def peek
      return if @capacity == 0
      @buffer[@bytesize - 1]
    end

    def back(amount : Int)
      abort "overflow" if amount > @bytesize
      @bytesize -= amount
    end

    def write_byte(other : UInt8)
      if @bytesize == @capacity
        if @buffer.null?
          @buffer = Pointer(UInt8).malloc_atomic(5 + HEADER_SIZE)
          @capacity = capacity_for_ptr @buffer
        else
          old_buffer = @buffer
          old_size = @capacity.to_usize + 1 + HEADER_SIZE
          @buffer = Pointer(UInt8).malloc_atomic(@bytesize.to_u32 + 1 + HEADER_SIZE)
          @capacity = capacity_for_ptr @buffer
          LibC.memcpy(@buffer, old_buffer, old_size)
        end
      end
      buffer[@bytesize] = other
      @bytesize += 1
    end

    def <<(other : String)
      other.each_byte do |byte|
        write_byte byte
      end
    end

    def <<(other : Slice(UInt8))
      other.each do |byte|
        write_byte byte
      end
    end

    def <<(other : Char)
      if other.ord <= 0xFF
        write_byte other.ord.to_u8
      else
        abort "TODO: support utf-8 for builder"
      end
    end

    def to_s : String
      abort "Can only invoke 'to_s' once on String::Builder" if @finished
      @finished = true

      write_byte 0u8

      header = @buffer.as({Int32, Int32, Int32}*)
      bytesize, length = String.calculate_length(buffer)
      header.value = {String::TYPE_ID, bytesize, length}
      @buffer.as(String)
    end

    def reset(capacity : Int32)
      @buffer = Pointer(UInt8).malloc_atomic(capacity.to_u32 + 1 + HEADER_SIZE)
      @capacity = capacity_for_ptr @buffer
      @bytesize = 0
      @finished = false
    end
  end

  def self.new(chars : UInt8*)
    size = LibC.strlen(chars)
    (new(size) { |buffer|
      LibC.strcpy buffer, chars
      String.calculate_length(buffer)
    }).not_nil!
  end

  def self.new(chars : UInt8*, bytesize, size = 0)
    (new(bytesize) { |buffer|
      LibC.strncpy buffer, chars, bytesize.to_usize
      if size == 0
        String.calculate_length buffer
      else
        {bytesize, size}
      end
    }).not_nil!
  end

  def self.new(bytes : Bytes)
    new bytes.to_unsafe
  end

  def self.new(capacity : Int)
    str = Pointer(UInt8).malloc_atomic(capacity.to_u64 + HEADER_SIZE + 1)
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
    {i, length}
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

  def starts_with?(str : String)
    return false if bytesize < str.bytesize
    LibC.strncmp(to_unsafe, str.to_unsafe, str.bytesize) == 0
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

  def [](idx : Int, count : Int)
    if count < 0
      end_idx = size + count
    else
      end_idx = idx + count - 1
    end
    abort "out of range" unless 0 <= idx < size && 0 <= end_idx < size
    builder = String::Builder.new count
    each_unicode_point do |char, i|
      if idx <= i <= end_idx
        builder << char
      elsif i > end_idx
        return builder.to_s
      end
    end
    return builder.to_s
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
            {bytesize, unisize}
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
        {bytesize, unisize}
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
