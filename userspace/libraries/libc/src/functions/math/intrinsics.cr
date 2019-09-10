lib Intrinsics
  fun ceil_f64 = "llvm.ceil.f64"(value : Float64) : Float64
  fun floor_f64 = "llvm.floor.f64"(value : Float64) : Float64
  fun pow_f64 = "llvm.pow.f64"(value : Float64, power : Float64) : Float64
  fun round_f64 = "llvm.round.f64"(value : Float64) : Float64
  fun sqrt_f32 = "llvm.sqrt.f32"(value : Float32) : Float32
  fun sqrt_f64 = "llvm.sqrt.f64"(value : Float64) : Float64
end

lib LibC
  fun abort
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