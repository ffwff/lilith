module Pmalloc
  extend self

  @@addr = 0u64
  class_property addr

  @@start = 0u64
  class_property start

  def alloc(size : USize)
    last = @@addr
    @@addr += size
    last
  end

  def alloca(size : USize)
    if (@@addr & 0xFFFF_FFFF_FFFF_F000) != 0
      @@addr = (@@addr & 0xFFFF_FFFF_FFFF_F000) + 0x1000
    end
    alloc(size)
  end
end

struct Pointer(T)
  def self.null
    new 0u64
  end

  def self.pmalloc(size : Int)
    ptr = new Pmalloc.alloc(size.to_usize * sizeof(T))
    memset ptr.as(UInt8*), 0u64, size.to_usize * sizeof(T)
    ptr
  end

  def self.pmalloc
    ptr = new Pmalloc.alloc(sizeof(T).to_usize)
    memset ptr.as(UInt8*), 0u64, sizeof(T).to_usize
    ptr
  end

  def self.pmalloc_a
    ptr = new Pmalloc.alloca(sizeof(T).to_usize)
    memset ptr.as(UInt8*), 0u64, sizeof(T).to_usize
    ptr
  end

  def self.malloc_atomic(size : Int = 1)
    __crystal_malloc_atomic64(size.to_u64 * sizeof(T)).as(T*)
  end

  def to_s(io)
    io.print "[0x"
    self.address.to_s io, 16
    io.print "]"
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
