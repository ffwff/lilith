fun strdup(str : LibC::String) : LibC::String
  if str.null?
    return Pointer(UInt8).null
  end
  new_str = calloc(strlen(str) + 1, 1).as(LibC::String)
  strcpy new_str, str
  new_str
end

fun strlen(str : LibC::String) : SizeT
  if str.null?
    return 0u32
  end
  i = 0u32
  while str[i] != 0
    i += 1
  end
  i
end

fun strcmp(s1 : LibC::String, s2 : LibC::String) : Int32
  while s1.value && (s1.value == s2.value)
    s1 += 1
    s2 += 1
  end
  (s1.value - s2.value).to_i32
end

fun strcpy(dst : LibC::String, src : LibC::String) : LibC::String
  return dst if dst.null?
  return src if src.null?
  retval = dst
  until src.value == 0
    dst.value = src.value
    src += 1
  end
  retval
end

# memory
fun memset(dst : UInt8*, c : UInt32, n : SizeT) : Void*
  i = 0
  while i < n
    dst[i] = c.to_u8
    i += 1
  end
  dst.as(Void*)
end

fun memcpy(dst : UInt8*, src : UInt8*, n : SizeT) : Void*
  i = 0
  while i < n
    dst[i] = src[i]
    i += 1
  end
  dst.as(Void*)
end
