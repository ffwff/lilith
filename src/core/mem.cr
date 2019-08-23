fun memset(dst : UInt8*, c : USize, n : USize) : Void*
  asm(
    "cld\nrep stosb"
    :: "{al}"(c.to_u8), "{rdi}"(dst), "{rcx}"(n)
    : "volatile", "memory"
  )
  dst.as(Void*)
end

fun memcpy(dst : UInt8*, src : UInt8*, n : USize) : Void*
  asm(
    "cld\nrep movsb"
    :: "{rdi}"(dst), "{rsi}"(src), "{rcx}"(n)
    : "volatile", "memory"
  )
  dst.as(Void*)
end
