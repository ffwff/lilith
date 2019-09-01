@[NoInline]
def zero_page(mem : UInt8*, npages : USize = 1)
  return if npages == 0
  count = npages * 0x1000
  asm("
    xor %rax, %rax
    pxor %xmm0, %xmm0
  1:
    movdqa %xmm0,     (%rcx, %rax)
    movdqa %xmm0, 0x10(%rcx, %rax)
    movdqa %xmm0, 0x20(%rcx, %rax)
    movdqa %xmm0, 0x30(%rcx, %rax)
    movdqa %xmm0, 0x40(%rcx, %rax)
    movdqa %xmm0, 0x50(%rcx, %rax)
    movdqa %xmm0, 0x60(%rcx, %rax)
    movdqa %xmm0, 0x70(%rcx, %rax)
    movdqa %xmm0, 0x80(%rcx, %rax)
    movdqa %xmm0, 0x90(%rcx, %rax)
    movdqa %xmm0, 0xa0(%rcx, %rax)
    movdqa %xmm0, 0xb0(%rcx, %rax)
    movdqa %xmm0, 0xc0(%rcx, %rax)
    movdqa %xmm0, 0xd0(%rcx, %rax)
    movdqa %xmm0, 0xe0(%rcx, %rax)
    movdqa %xmm0, 0xf0(%rcx, %rax)
    add $$0x100, %rax
    cmp %rdx, %rax
    jne 1b
  "
    :: "{rcx}"(mem), "{rdx}"(count)
    : "volatile", "memory", "{rax}", "{xmm0}"
  )
end