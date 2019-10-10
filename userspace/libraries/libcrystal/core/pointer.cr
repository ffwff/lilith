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

  def self.malloc(size)
    Gc.unsafe_malloc(size.to_u64).as(T*)
  end
end
