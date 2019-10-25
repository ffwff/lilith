fun memset(dst : UInt8*, c : USize, n : USize) : Void*
  asm(
    "cld\nrep stosb"
          :: "{al}"(c.to_u8), "{rdi}"(dst), "{rcx}"(n)
          : "volatile", "memory"
  )
  dst.as(Void*)
end

@[AlwaysInline]
def memset_long(dst : UInt32*, c : UInt32, n : USize)
  asm(
    "cld\nrep stosl"
          :: "{eax}"(c), "{rdi}"(dst), "{rcx}"(n)
          : "volatile", "memory"
  )
end

fun memcpy(dst : UInt8*, src : UInt8*, n : USize) : Void*
  asm(
    "shrq $$3, %rcx
    andl $$7, %edx
    cld
    rep movsq
    movl %edx, %ecx
    rep movsb"
          :: "{rdi}"(dst), "{rsi}"(src), "{rcx}"(n)
          : "volatile", "memory"
  )
  dst.as(Void*)
end

fun memcmp(s1 : UInt8*, s2 : UInt8*, n : Int32) : Int32
  while n > 0 && (s1.value == s2.value)
    s1 += 1
    s2 += 1
    n -= 1
  end
  return 0 if n == 0
  (s1.value - s2.value).to_i32
end
