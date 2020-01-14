fun getenv(name : UInt8*) : UInt8*
  Pointer(UInt8).null
end

fun setenv(name : UInt8*, value : UInt8*, overwrite : LibC::Int) : LibC::Int
  0
end
