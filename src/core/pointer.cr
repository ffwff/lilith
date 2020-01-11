struct Pointer(T)
  def self.null
    new 0u64
  end

  def self.malloc_atomic(size : Int = 1)
    __crystal_malloc_atomic64(size.to_u64 * sizeof(T)).as(T*)
  end

  def to_s(io)
    io.print "0x"
    self.address.to_s io, 16
  end

  def null?
    self.address == 0
  end

  def [](offset : Int)
    (self + offset.to_i64).value
  end

  def []=(offset : Int, data : T)
    (self + offset.to_i64).value = data
  end

  def +(offset : Int)
    self + offset.to_i64
  end

  def -(offset : Int)
    self + (offset.to_i64 * -1)
  end

  def ==(other)
    self.address == other.address
  end

  def !=(other)
    self.address != other.address
  end

  def <=>(other : self)
    address <=> other.address
  end
end
