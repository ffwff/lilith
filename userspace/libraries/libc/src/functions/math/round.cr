fun round(x : Float64) : Float64
  ee = x.unsafe_as(UInt64).unsafe_shr(52) & 0x7ff
  if ee == 0x7ff
    return x
  end
  truncated = trunc(x)
  decimal = x - truncated
  if decimal == 0.5
    if x < 0.0f64
      truncated -= 1.0f64
    else
      truncated += 1.0f64
    end
  end
  truncated
end
