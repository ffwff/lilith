lib LibC
  fun sscanf(str : UInt8*, fmt : UInt8*, ...) : LibC::Int
end

# string conversion
fun strtod(nptr : UInt8*, endptr : UInt8**) : Float64
  retval = 0.0f64
  written = LibC.sscanf nptr, "%lf", pointerof(retval)
  unless endptr.null?
    endptr.value = nptr + written
  end
  retval
end

fun strtof(nptr : UInt8*, endptr : UInt8**) : Float32
  retval = 0.0f32
  written = LibC.sscanf nptr, "%f", pointerof(retval)
  unless endptr.null?
    endptr.value = nptr + written
  end
  retval
end

fun strtol(nptr : UInt8*, endptr : UInt8**, base : LibC::Int) : LibC::Long
  abort
  0.to_long
end

fun strtoul(nptr : UInt8*, endptr : UInt8**, base : LibC::Int) : LibC::ULong
  abort
  0.to_ulong
end

fun atof(nptr : UInt8*) : Float64
  retval = 0.0f64
  written = LibC.sscanf nptr, "%lf", pointerof(retval)
  retval
end

fun atoi(nptr : UInt8*) : LibC::Int
  abort
  0
end

fun atol(nptr : UInt8*) : LibC::Long
  abort
  0.to_long
end

# environ
fun getenv(name : UInt8*) : UInt8*
  Pointer(UInt8).null
end

fun setenv(name : UInt8*, value : UInt8*, overwrite : LibC::Int) : LibC::Int
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
fun system(command : UInt8*) : LibC::Int
  0
end
