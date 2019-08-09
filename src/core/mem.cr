fun memset(dst : UInt8*, c : USize, n : USize) : Void*
  asm(
    "cld\nrep stosb"
    :: "{al}"(c.to_u8), "{edi}"(dst), "{ecx}"(n)
    : "volatile", "memory"
  )
  dst.as(Void*)
end

fun memcpy(dst : UInt8*, src : UInt8*, n : USize) : Void*
  i = 0
  while i < n
    dst[i] = src[i]
    i += 1
  end
  dst.as(Void*)
end
