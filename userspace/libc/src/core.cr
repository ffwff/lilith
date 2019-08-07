lib LibC
  alias String = Int8*
  alias UString = UInt8*
  alias Pid = Int32
  alias SizeT = UInt32
  alias SSizeT = Int32
end

# Ints
struct Int
  # needed by SimpleAllocator
  def ~
    self ^ -1
  end
end

# Object
class Object

  def unsafe_as(type : T.class) forall T
    x = self
    pointerof(x).as(T*).value
  end

  macro property(*names)
    {% for name in names %}
    def {{ name.id }}
      @{{ name.id }}
    end
    def {{ name.id }}=(@{{ name.id }})
    end
    {% end %}
  end

end

# Pointers
struct Pointer(T)
  def self.null
    new 0u64
  end

  def self.malloc
    MALLOC.malloc(sizeof(T).to_u32).as(T*)
  end

  def free
    MALLOC.free(self.as(Void*))
  end

  #
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

  #
  def null?
    address == 0
  end
end

# Arrays
struct StaticArray(T, N)
  def to_unsafe : Pointer(T)
    pointerof(@buffer)
  end
end

# Strings
class String
  def to_unsafe
    pointerof(@c)
  end
end

# Enums
struct Enum
  def ==(other)
    value == other.value
  end

  def !=(other)
    value != other.value
  end

  def ===(other)
    value == other.value
  end

  def |(other : self)
    self.class.new(value | other.value)
  end

  def &(other : self)
    self.class.new(value & other.value)
  end

  def ~
    self.class.new(~value)
  end

  def includes?(other : self)
    (value & other.value) != 0
  end
end