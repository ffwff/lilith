# NOTE: intrinsic cos/sin functions generate calls to libc's cos/sin functions

private MAGIC_RND =                     6755399441055744.0f64
private NEGPI     = -3.14159265358979323846264338327950288f64
private INVPI     =  0.31830988618379067153776752674502872f64
private A         = -0.00018488140186756154724131984146140f64
private B         =  0.00831189979755905285208061883395203f64
private C         = -0.16665554092439083255783316417364403f64
private D         =  0.99999906089941981157664940838003531f64

# https://gist.github.com/orlp/1501b5faa56b592683d5

fun sin(arg : Float64) : Float64
  # Range-reduce to [-pi/2, pi/2] and store if period is odd.
  u_x = INVPI * arg + MAGIC_RND
  u_i = u_x.unsafe_as(UInt64)
  odd_period = u_i.unsafe_shl(63)
  u_x = arg + NEGPI * (u_i & 0xffffffff).to_i32

  # 7th degree odd polynomial followed by IEEE754 sign flip on odd periods.
  x2 = u_x * u_x
  p = D + x2 * (C + x2 * (B + x2 * A))
  u_i = u_x.unsafe_as(UInt64) ^ odd_period
  u_x = u_i.unsafe_as(Float64)
  u_x * p
end

private PI_2 = 1.57079632679489661923132169163975144f64

fun cos(arg : Float64) : Float64
  sin(arg + PI_2)
end

fun tan(arg : Float64) : Float64
  sin(arg) / cos(arg)
end

# hyp functions
fun tanh(arg : Float64) : Float64
  # TODO
  0.0f64
end
fun sinh(arg : Float64) : Float64
  # TODO
  0.0f64
end
fun cosh(arg : Float64) : Float64
  # TODO
  0.0f64
end

# arc- functions
fun atan2(arg : Float64) : Float64
  # TODO
  0.0f64
end
