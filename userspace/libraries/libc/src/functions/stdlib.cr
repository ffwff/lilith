# string conversion
fun strtol(nptr : LibC::String, endptr : LibC::String*, base : LibC::Int) : LibC::Long
  abort
  0
end

fun strtoul(nptr : LibC::String, endptr : LibC::String*, base : LibC::Int) : LibC::ULong
  abort
  0u32
end

fun strtod(nptr : LibC::String, endptr : LibC::String*) : Float64
  abort
  0.0f64
end

fun atoi(nptr : LibC::String) : LibC::Int
  abort
  0
end

fun atol(nptr : LibC::String) : LibC::Long
  abort
  0
end

fun atof(nptr : LibC::String) : Float32
  abort
  0.0f32
end

# environ
fun getenv(name : LibC::String) : LibC::String
  LibC::String.null
end

fun setenv(name : LibC::String, value : LibC::String, overwrite : LibC::Int) : LibC::Int
  0
end

# rand
fun rand : LibC::Int
  # TODO: chosen by an fair dice roll
  # guaranteed to be random
  4
end

# abs
fun abs(j : LibC::Int) : LibC::Int
  j > 0 ? j : (j * -1)
end

fun labs(j : LibC::Long) : LibC::Long
  j > 0 ? j : (j * -1)
end

fun llabs(j : LibC::LongLong) : LibC::LongLong
  j > 0 ? j : (j * -1)
end

# spawn
fun system(command : LibC::String) : LibC::Int
  0
end