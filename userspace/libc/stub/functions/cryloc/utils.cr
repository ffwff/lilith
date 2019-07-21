alias SizeT = UInt32
alias SSizeT = Int32

struct Int
  def to_ssize
    self.to_u32
  end
end

macro cryloc_max(a, b)
  {{a}} >= {{b}} ? {{a}} : {{b}}
end

macro cryloc_align(size, align)
  (({{size}} + {{align}} - 1) & ~({{align}} - 1))
end

@[AlwaysInline]
def cryloc_memcpy(dest : UInt8*, src : UInt8*, n : UInt64)
  LibC.memcpy(dest, src, n.to_u32).as(UInt8*)
end

@[AlwaysInline]
def cryloc_memset(s : UInt8*, c : Int32, n : UInt32) : UInt8*
  LibC.memset(s, c, n).as(UInt8*)
end
