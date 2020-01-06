fun modf(arg : Float64, iptr : Float64*) : Float64
  ee = arg.unsafe_as(UInt64).unsafe_shr(52) & 0x7ff
  if ee == 0x7ff
    iptr.value = arg
    return arg
  end
  truncated = trunc(arg)
  decimal = arg - truncated
  iptr.value = truncated
  decimal
end
