lib LibIntrinsics
  fun ceil_f64 = "llvm.ceil.f64"(value : Float64) : Float64
  fun floor_f64 = "llvm.floor.f64"(value : Float64) : Float64
  fun pow_f64 = "llvm.pow.f64"(value : Float64, power : Float64) : Float64
  fun round_f64 = "llvm.round.f64"(value : Float64) : Float64
end

fun floor(arg : Float64) : Float64
  LibIntrinsics.floor_f64 arg
end

fun ceil(arg : Float64) : Float64
  LibIntrinsics.ceil_f64 arg
end

fun round(arg : Float64) : Float64
  LibIntrinsics.round_f64 arg
end

fun pow(arg : Float64, exp : Float64) : Float64
  LibIntrinsics.pow_f64 arg, exp
end

@[Naked]
fun fmod
  asm("
     fldl 12(%esp)
     fldl 4(%esp)
  1: fprem
     fnstsw %ax
     sahf
     jp 1b
     fstp %st(1)
     ret
  ")
end