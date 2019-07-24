fun memset(dst : UInt8*, c : UInt32, n : UInt32) : Void*
  i = 0
  while i < n
    dst[i] = c.to_u8
    i += 1
  end
  dst.as(Void*)
end

fun memcpy(dst : UInt8*, src : UInt8*, n : UInt32) : Void*
  i = 0
  while i < n
    dst[i] = src[i]
    i += 1
  end
  dst.as(Void*)
end
