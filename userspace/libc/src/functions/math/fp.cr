fun frexp(x : Float64, e : Int32*) : Float64
  ee = x.unsafe_as(UInt64).unsafe_shr(52) & 0x7ff
  if ee == 0x7ff
    return x
  elsif ee == 0
    if x > 0
      m = 0x43f0000000000000u64
      x = frexp(x * m.unsafe_as(Float64), e)
      e.value -= 64
    else
      e.value = 0
    end
  end

  e.value = (ee - 0x3fe).to_i32

  y = x.unsafe_as(UInt64)
  y &= 0x800fffffffffffffu64
  y |= 0x3fe0000000000000u64
  y.unsafe_as(Float64)
end

fun modf(arg : Float64, iptr : Float64) : Float64
  # TODO
  LibC.abort
  0.0f64
end