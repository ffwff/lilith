struct Pointer(T)
  include Comparable(self)

  def self.null
    new 0u64
  end

  def self.malloc_atomic(size : Int = 1)
    __crystal_malloc_atomic64(size.to_u64 * sizeof(T)).as(T*)
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

  def -(other : Int)
    self + (-other.to_i64!)
  end

  def <=>(other : self)
    address <=> other.address
  end

  def to_s(io)
    io << "0x"
    address.to_s(io, base: 16)
  end

  def unmap_from_memory(size : Int = -1)
    LibC.munmap self, size.to_u64
  end
end
