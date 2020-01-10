.global asin
.type asin,@function
asin:
  movq %xmm0, -8(%rsp)
  fldl -8(%rsp)
  mov $0x3ff0000000000000, %rax
  movq %rax, %xmm2
  mulsd %xmm0, %xmm0
  subsd %xmm0, %xmm2
  sqrtsd %xmm0, %xmm0
  movq %xmm0, -8(%rsp)
  fldl -8(%rsp)
  fpatan
  fstpl -8(%rsp)
  movq -8(%rsp), %xmm0
  ret
