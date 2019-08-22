# string conversion
fun strtol(nptr : LibC::String, endptr : LibC::String*, base : LibC::Int) : LibC::Long
  abort
  0
end

fun strtoul(nptr : LibC::String, endptr : LibC::String*, base : LibC::Int) : LibC::ULong
  abort
  0u32
end

# environ
fun getenv(name : LibC::String) : LibC::String
  LibC::String.null
end

fun setenv(name : LibC::String, value : LibC::String, overwrite : LibC::Int) : LibC::Int
  0
end