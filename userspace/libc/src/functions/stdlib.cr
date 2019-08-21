fun strtoul(nptr : LibC::String, endptr : LibC::String*, base : LibC::Int) : LibC::UInt
  0u32
end

fun getenv(name : LibC::String) : LibC::String
  LibC::String.null
end

fun setenv(name : LibC::String, value : LibC::String, overwrite : LibC::Int) : LibC::Int
  0
end