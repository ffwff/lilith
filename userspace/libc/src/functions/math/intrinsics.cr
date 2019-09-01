lib Intrinsics
  fun ceil_f64 = "llvm.ceil.f64"(value : Float64) : Float64
  fun floor_f64 = "llvm.floor.f64"(value : Float64) : Float64
  fun pow_f64 = "llvm.pow.f64"(value : Float64, power : Float64) : Float64
  fun round_f64 = "llvm.round.f64"(value : Float64) : Float64
  fun sqrt_f32 = "llvm.sqrt.f32"(value : Float32) : Float32
  fun sqrt_f64 = "llvm.sqrt.f64"(value : Float64) : Float64
  fun sin_f64 = "llvm.sin.f64"(value : Float64) : Float64
  fun cos_f64 = "llvm.cos.f64"(value : Float64) : Float64
end

lib LibC
  fun abort
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

fun sqrt(arg : Float64) : Float64
  Intrinsics.sqrt_f64 arg
end
fun sqrtf(arg : Float32) : Float32
  Intrinsics.sqrt_f32 arg
end

fun hypot(x : Float64, y : Float64) : Float64
  sqrt(x*x + y*y)
end

fun sin(arg : Float64) : Float64
  Intrinsics.sin_f64 arg
end

fun cos(arg : Float64) : Float64
  Intrinsics.cos_f64 arg
end
fun acos(arg : Float64) : Float64
  # TODO
  LibC.abort
  0.0f64
end

fun tan(arg : Float64) : Float64
  # TODO
  LibC.abort
  0.0f64
end

fun atan2(arg : Float64) : Float64
  # TODO
  LibC.abort
  0.0f64
end

fun modf(arg : Float64, iptr : Float64) : Float64
  # TODO
  LibC.abort
  0.0f64
end