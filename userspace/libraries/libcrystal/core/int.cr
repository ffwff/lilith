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

  # unsafe math
  def /(other)
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

  # math
  def ~
    self ^ -1
  end

  def ===(other)
    self == other
  end

  def abs
    self >= 0 ? self : self * -1
  end

  # bit manips
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

  # format
  private BASE = "0123456789abcdefghijklmnopqrstuvwxyz"

  private def each_digit(base = 10, &block)
    s = uninitialized UInt8[128]
    sign = self < 0
    n = self.abs
    i = 0
    while i < 128
      s[i] = BASE.bytes[n % base]
      i += 1
      break if (n /= base) == 0
    end
    if sign
      yield '-'.ord.to_u8
    end
    i -= 1
    while true
      yield s[i]
      break if i == 0
      i -= 1
    end
  end
  
  def to_s(io, base = 10)
    each_digit(base) do |ch|
      io.putc ch
    end
  end

  def to_usize
    self.to_u64
  end

  def to_isize
    self.to_i64
  end
end

alias ISize = Int64
alias USize = UInt64

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

