lib LibC
  alias String = UInt8*
end

alias Pid = Int32
alias SizeT = UInt32

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

end

# Pointers
struct Pointer(T)
  def self.null
    new 0u64
  end

  def self.malloc
    malloc(sizeof(T).to_u64).as(T*)
  end

  def free
    free(self.as(Void*))
  end

  #
  def [](offset : Int)
    (self + offset.to_i64).value
  end

  def []=(offset : Int, data : T)
    (self + offset.to_i64).value = data
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
