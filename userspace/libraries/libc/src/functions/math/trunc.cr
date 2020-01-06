fun trunc(x : Float64) : Float64
  ee = x.unsafe_as(UInt64).unsafe_shr(52) & 0x7ff
  if ee == 0x7ff
    return x
  end
  x.to_i64.to_f64
end
