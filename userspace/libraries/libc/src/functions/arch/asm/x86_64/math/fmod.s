.global fmod

fmod:
  movq %xmm1, 8(%rsp)
  fldl 8(%rsp)
  movq %xmm0, 16(%rsp)
  fldl 16(%rsp)
1:fprem
  fnstsw %ax
  sahf
  jp 1b
  fstp %st(1)
  fstpl 8(%rsp)
  movq 8(%rsp), %xmm0
  ret
