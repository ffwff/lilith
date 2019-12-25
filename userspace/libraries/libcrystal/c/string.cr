lib LibC
  fun strlen(str : LibC::UString) : LibC::SizeT
  fun strcpy(dest : LibC::UString, src : LibC::UString) : LibC::UString
  fun strncpy(dest : LibC::UString, src : LibC::UString, size : LibC::SizeT) : LibC::UString
  fun strncmp(dest : LibC::UString, src : LibC::UString, size : LibC::SizeT) : LibC::Int
  fun memcmp(s1 : LibC::UString, s2 : LibC::UString, n : LibC::SizeT) : LibC::Int
  fun memcpy(dest : Void*, src : Void*, n : SizeT) : Void*
  fun memmove(dest : Void*, src : Void*, n : SizeT) : Void*
  fun memset(dest : Void*, c : LibC::Int, n : SizeT) : Void*
end
