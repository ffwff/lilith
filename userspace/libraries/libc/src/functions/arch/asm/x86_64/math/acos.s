# use acos(x) = atan2(fabs(sqrt((1-x)*(1+x))), x)

.global acos
.type acos,@function
acos:
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
