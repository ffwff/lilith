lib LibC
  alias Pid = LibC::Int

  alias Int = Int32
  alias UInt = UInt32
  alias LongLong = Int64
  alias ULongLong = UInt64

  {% if flag?(:bits32) %}
    alias SizeT = UInt32
    alias SSizeT = Int32
    alias Long = Int32
    alias ULong = UInt32
  {% else %}
    alias SizeT = UInt64
    alias SSizeT = Int64
    alias Long = Int64
    alias ULong = UInt64
  {% end %}
end

struct Tuple
  def self.new(*args : *T)
    args
  end
end

# Bools
struct Bool
  def to_int
    self ? 1 : 0
  end
end

# Ints
struct Int
  def to_int
    self.to_i32
  end

  def to_uint
    self.to_u32
  end

  def to_longlong
    self.to_i64
  end

  def to_ulonglong
    self.to_u64
  end

  {% if flag?(:bits32) %}
    def to_long
      self.to_i32
    end

    def to_ulong
      self.to_u32
    end

    def to_usize
      self.to_u32
    end

    def to_isize
      self.to_i32
    end
  {% else %}
    def to_long
      self.to_i64
    end

    def to_ulong
      self.to_u64
    end

    def to_usize
      self.to_u64
    end

    def to_isize
      self.to_i64
    end
  {% end %}

  def <<(other)
    self.unsafe_shl other
  end

  def >>(other)
    self.unsafe_shr other
  end

  def //(other)
    self.unsafe_div other
  end

  def %(other)
    self.unsafe_mod other
  end

  def ===(other)
    self == other
  end

  def times(&block)
    i = 0
    while i < self
      yield i
      i += 1
    end
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
    Malloc.malloc(sizeof(T).to_usize).as(T*)
  end

  def self.malloc(sz)
    Malloc.malloc(sizeof(T).to_usize * sz).as(T*)
  end

  def realloc(sz)
    Malloc.realloc(self.as(Void*), sizeof(T).to_usize * sz).as(T*)
  end

  def free
    Malloc.free(self.as(Void*))
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

  def size
    N
  end

  def [](idx : Int)
    to_unsafe[idx]
  end

  def []=(idx : Int, val : T)
    to_unsafe[idx] = val
  end
end

# Strings
class String
  def to_unsafe
    pointerof(@c)
  end

  def size
    @length
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

struct Proc
  def self.new(pointer : Void*, closure_data : Void*)
    func = {pointer, closure_data}
    ptr = pointerof(func).as(self*)
    ptr.value
  end
end

struct Char
  def ===(other : self)
    self == other
  end
end

@[Weak]
fun __crystal_once_init : Void*
  Pointer(Void).new 0
end

@[Weak]
fun __crystal_once(state : Void*, flag : Bool*, initializer : Void*)
  unless flag.value
    Proc(Nil).new(initializer, Pointer(Void).new 0).call
    flag.value = true
  end
end
