lib LibC
  alias String = UInt8*
  fun strlen(str : String) : UInt32
  fun strcpy(dst : String, src : String)

  fun memcpy(dest : Void*, src : Void*, n : UInt32) : Void*
  fun memset(s : Void*, c : UInt8, n : UInt32) : Void*

  fun malloc(sz : UInt32) : Void*
  fun calloc(nmemb : UInt32, sz : UInt32) : Void*
  fun free(addr : Void*)
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

# Pointers
struct Pointer(T)
  def self.null
    new 0u64
  end

  @[AlwaysInline]
  def self.malloc
    LibC.malloc(sizeof(T).to_u64).as(T*)
  end

  @[AlwaysInline]
  def free
    LibC.free(self.as(Void*))
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
