def zero_page(mem : UInt8*, npages : UInt32 = 1)
  return if npages == 0
  count = npages * 0x1000
  asm("
    xor %eax, %eax
    pxor %xmm0, %xmm0
  1:
    movdqa %xmm0,     (%ecx, %eax)
    movdqa %xmm0, 0x10(%ecx, %eax)
    movdqa %xmm0, 0x20(%ecx, %eax)
    movdqa %xmm0, 0x30(%ecx, %eax)
    movdqa %xmm0, 0x40(%ecx, %eax)
    movdqa %xmm0, 0x50(%ecx, %eax)
    movdqa %xmm0, 0x60(%ecx, %eax)
    movdqa %xmm0, 0x70(%ecx, %eax)
    movdqa %xmm0, 0x80(%ecx, %eax)
    movdqa %xmm0, 0x90(%ecx, %eax)
    movdqa %xmm0, 0xa0(%ecx, %eax)
    movdqa %xmm0, 0xb0(%ecx, %eax)
    movdqa %xmm0, 0xc0(%ecx, %eax)
    movdqa %xmm0, 0xd0(%ecx, %eax)
    movdqa %xmm0, 0xe0(%ecx, %eax)
    movdqa %xmm0, 0xf0(%ecx, %eax)
    add $$0x100, %eax
    cmp %edx, %eax
    jne 1b
  "
    :: "{ecx}"(mem), "{edx}"(count)
    : "volatile", "memory", "{eax}"
  )
end