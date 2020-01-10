require "./static_array.cr"

struct Int
  alias Signed = Int8 | Int16 | Int32 | Int64 | Int128
  alias Unsigned = UInt8 | UInt16 | UInt32 | UInt64 | UInt128
  alias Primitive = Signed | Unsigned

  def times
    x = 0
    while x < self
      yield x
      x += 1
    end
  end

  def -
    self * -1
  end

  def //(other)
    self.unsafe_div other
  end

  def %(other)
    self.unsafe_mod other
  end

  def <<(other)
    self.unsafe_shl other
  end

  def >>(other)
    self.unsafe_shr other
  end

  def ~
    self ^ -1
  end

  def ===(other)
    self == other
  end

  def abs
    self >= 0 ? self : self * -1
  end

  def clamp(min, max)
    return min if self < min
    return max if self > max
    self
  end

  def div_ceil(other : Int)
    (self + (other - 1)) // other
  end

  def find_first_zero : Int
    Intrinsics.counttrailing32(~self.to_i32, true)
  end

  def nearest_power_of_2
    n = self - 1
    while (n & (n - 1)) != 0
      n = n & (n - 1)
    end
    n << 1
  end

  def lowest_power_of_2
    x = self
    x = x | (x >> 1)
    x = x | (x >> 2)
    x = x | (x >> 4)
    x = x | (x >> 8)
    x = x | (x >> 16)
    x - (x >> 1)
  end

  private BASE = "0123456789abcdefghijklmnopqrstuvwxyz"

  private def each_digit(base = 10, &block)
    s = uninitialized UInt8[128]
    sign = self < 0
    n = self.abs
    i = 0
    while i < 128
      s[i] = BASE.to_unsafe[n % base]
      i += 1
      break if (n //= base) == 0
    end
    if sign
      yield '-'
    end
    i -= 1
    while true
      yield s[i].unsafe_chr
      break if i == 0
      i -= 1
    end
  end

  def hash(hasher)
    hasher.hash self
  end

  def to_s(base : Int = 10)
    s = uninitialized UInt8[128]
    sign = self < 0
    n = self.abs
    i = 0
    while i < 128
      s[i] = BASE.to_unsafe[n % base]
      i += 1
      break if (n //= base) == 0
    end
    if sign
      s[i] = '-'.ord.to_u8
      i += 1
    end
    i -= 1
    (String.new(i + 1) { |buffer|
      j = 0
      while true
        buffer[j] = s[i]
        j += 1
        break if i == 0
        i -= 1
      end
      {j, j}
    }).not_nil!
  end

  def to_s(io, base : Int = 10)
    each_digit(base) do |ch|
      io << ch
    end
  end

  {% if flag?(:bits32) %}
    def to_usize
      self.to_u32
    end

    def to_isize
      self.to_i32
    end
  {% else %}
    def to_usize
      self.to_u64
    end

    def to_isize
      self.to_i64
    end
  {% end %}

  def <=>(other : Int) : Int32
    self > other ? 1 : (self < other ? -1 : 0)
  end
end

{% if flag?(:bits32) %}
  alias USize = UInt32
  alias ISize = Int32
{% else %}
  alias USize = UInt64
  alias ISize = Int64
{% end %}

struct Int8
  MIN = -128_i8
  MAX =  127_i8

  def self.new(value)
    value.to_i8
  end
end

struct Int16
  MIN = -32768_i16
  MAX =  32767_i16

  def self.new(value)
    value.to_i16
  end
end

struct Int32
  MIN = -2147483648_i32
  MAX =  2147483647_i32

  def self.new(value)
    value.to_i32
  end
end

struct Int64
  MIN = -9223372036854775808_i64
  MAX =  9223372036854775807_i64

  def self.new(value)
    value.to_i64
  end
end

struct UInt8
  MIN =   0_u8
  MAX = 255_u8

  def abs
    self
  end

  def self.new(value)
    value.to_u8
  end
end

struct UInt16
  MIN =     0_u16
  MAX = 65535_u16

  def abs
    self
  end

  def self.new(value)
    value.to_u16
  end
end

struct UInt32
  MIN =          0_u32
  MAX = 4294967295_u32

  def abs
    self
  end

  def self.new(value)
    value.to_u32
  end

  def popcount
    Intrinsics.popcount32 self
  end
end

struct UInt64
  MIN =                    0_u64
  MAX = 18446744073709551615_u64

  def abs
    self
  end

  def self.new(value)
    value.to_u64
  end
end
