lib LibC
  {% if flag?(:i386) %}
    type VaList = Void*
  {% elsif flag?(:x86_64) %}
    struct VaListTag
      gp_offset : UInt
      fp_offset : UInt
      overflow_arg_area : Void*
      reg_save_area : Void*
    end

    type VaList = VaListTag[1]
  {% end %}
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
    retval = yield new(ap)
    Intrinsics.va_end pointerof(ap)
    retval
  end

  def self.copy(other : LibC::VaList*)
    ap = uninitialized LibC::VaList
    Intrinsics.va_copy pointerof(ap), other
    retval = yield new(ap)
    Intrinsics.va_end pointerof(ap)
    retval
  end

  @[Primitive(:va_arg)]
  def next(type)
  end
end
