struct Char
  def to_s(io)
    c = self.ord.to_u8
    io.write Bytes.new(pointerof(c), 1)
  end

  def ===(other)
    self == other
  end
end
