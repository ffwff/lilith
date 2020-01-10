.global pow
.type pow,@function
pow: # x ^ y = 2 ^(y*log2(x))
  movq %xmm1, -8(%rsp) # x
  fldl -8(%rsp)
  movq %xmm0, -8(%rsp) # y
  fldl -8(%rsp)
  fyl2x # y * log2(x)
  fld1
  fld %st(1)
  fprem
  f2xm1
  faddp
  fscale
  fstpl -8(%rsp)
  movq -8(%rsp), %xmm0
  ret
