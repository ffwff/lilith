@[NoInline]
def zero_page(mem : UInt8*, npages : USize = 1)
  return if npages == 0
  count = npages * 0x200
  asm("cld\nrep stosq"
    :: "{rax}"(0), "{rdi}"(mem), "{rcx}"(count)
    : "volatile", "memory"
  )
end