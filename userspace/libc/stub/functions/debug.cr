def dbg(str : String)
  buf = uninitialized LibC::SyscallStringArgument
  buf.str = str.to_unsafe
  buf.len = str.size
  sysenter(SC_DBG, pointerof(buf).address.to_u32).to_i32
end

private BASE = "0123456789abcdefghijklmnopqrstuvwxyz"

struct Int
  private BASE = "0123456789abcdefghijklmnopqrstuvwxyz"

  private def internal_to_s(base = 10)
    s = uninitialized UInt8[128]
    sign = self < 0
    n = self.abs
    i = 0
    while i < 128
      s.to_unsafe[i] = BASE.to_unsafe[n.unsafe_mod(base)]
      i += 1
      break if (n = n.unsafe_div(base)) == 0
    end
    if sign
      yield '-'.ord.to_u8
    end
    i -= 1
    while true
      yield s.to_unsafe[i]
      break if i == 0
      i -= 1
    end
  end

  def dbg(base = 10)
    internal_to_s(base) do |ch|
      s = uninitialized UInt8[1]
      s.to_unsafe[0] = ch
      buf = uninitialized LibC::SyscallStringArgument
      buf.str = s.to_unsafe
      buf.len = 1
      sysenter(SC_DBG, pointerof(buf).address.to_u32).to_i32
    end
  end

  def abs
    self >= 0 ? self : self * -1
  end

end

struct Pointer
  def dbg
    dbg "[0x"
    self.address.dbg 16
    dbg "]"
  end
end

class String
  def size
    @length
  end
end