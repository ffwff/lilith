lib Intrinsics
  fun ceil_f64 = "llvm.ceil.f64"(value : Float64) : Float64
  fun floor_f64 = "llvm.floor.f64"(value : Float64) : Float64
  fun pow_f64 = "llvm.pow.f64"(value : Float64, power : Float64) : Float64
  fun round_f64 = "llvm.round.f64"(value : Float64) : Float64
end

fun floor(arg : Float64) : Float64
  Intrinsics.floor_f64 arg
end

fun ceil(arg : Float64) : Float64
  Intrinsics.ceil_f64 arg
end

fun round(arg : Float64) : Float64
  Intrinsics.round_f64 arg
end

fun pow(arg : Float64, exp : Float64) : Float64
  Intrinsics.pow_f64 arg, exp
end