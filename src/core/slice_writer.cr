class SliceWriter
  getter slice, offset

  def initialize(@slice : Slice(UInt8), @skip = -1)
    @offset = 0
  end

  macro fwrite?(writer, data)
    unless ({{ writer }} << {{ data }})
      return writer.offset
    end
  end

  def putc(ch)
    if @skip > 0
      @skip -= 1
      return
    end
    @slice[@offset] = ch
    @offset += 1
  end

  def print(ch : Char)
    putc(ch.ord.to_u8)
  end

  def print(ch : Int32)
    putc(ch.to_u8)
  end

  def print(str : String)
    str.each_byte do |ch|
      putc(ch)
    end
  end

  def print(*args)
    args.each do |arg|
      arg.to_s self
    end
  end

  def <<(other)
    other.to_s self
    @offset != @slice.size
  end
end
