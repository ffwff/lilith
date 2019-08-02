lib LibC
  type VaList = Void*
end

struct VaList
  def to_unsafe
    @to_unsafe
  end

  def initialize(@to_unsafe : LibC::VaList)
  end

  def self.open
    ap = uninitialized LibC::VaList
    Intrinsics.va_start pointerof(ap)
    begin
      yield new(ap)
    ensure
      Intrinsics.va_end pointerof(ap)
    end
  end
end
