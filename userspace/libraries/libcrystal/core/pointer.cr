struct Pointer(T)
  def self.null
    new 0u64
  end

  def self.malloc(size)
    Gc.unsafe_malloc(size.to_u64 * sizeof(T)).as(T*)
  end

  def self.malloc_atomic(size)
    Gc.unsafe_malloc(size.to_u64 * sizeof(T), true).as(T*)
  end

  def realloc(size)
    Gc.realloc(self.as(Void*), size.to_u64).as(T*)
  end

  def null?
    self.address == 0u64
  end

  def [](offset)
    (self + offset).value
  end

  def []=(offset, value : T)
    (self + offset).value = value
  end

  def ==(other)
    self.address == other.address
  end

  def +(other : Int)
    self + other.to_i64
  end

  def +(other : Nil)
    self
  end

  def to_s(io)
    io << "0x"
    address.to_s(io, base: 16)
  end
end
