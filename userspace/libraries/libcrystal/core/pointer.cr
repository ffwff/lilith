struct Pointer(T)
  def self.null
    new 0u64
  end

  def [](offset)
    (self + offset).value
  end

  def []=(offset, value : T)
    (self + offset).value = value
  end

  def +(other : Int)
    self + other.to_i64
  end

  def +(other : Nil)
    self
  end
end
