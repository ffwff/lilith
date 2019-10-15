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

  def div_ceil(other : Int)
    (self + (other - 1)) // other
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

  def each_digit(base = 10, &block)
    s = uninitialized UInt8[128]
    sign = self < 0
    n = self.abs
    i = 0
    while i < 128
      s[i] = BASE.bytes[n % base]
      i += 1
      break if (n //= base) == 0
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

  def to_gcstr(base = 10)
    s = uninitialized UInt8[128]
    sign = self < 0
    n = self.abs
    i = 0
    while i < 128
      s[i] = BASE.bytes[n % base]
      i += 1
      break if (n //= base) == 0
    end
    if sign
      s[i] = '-'.ord.to_u8
    else
      i -= 1
    end
    str = GcString.new(i + 1)
    j = 0
    while true
      str[j] = s[i]
      break if i == 0
      j += 1
      i -= 1
    end
    str
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

module Math
  extend self
  def min(a, b)
    a < b ? a : b
  end

  def max(a, b)
    a > b ? a : b
  end

  def clamp(x, min, max)
    return min if x < min
    return max if x > max
    x
  end
end
