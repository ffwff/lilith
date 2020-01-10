.global log10
.type log10,@function
log10:
  movq %xmm0, -8(%rsp)
  fldlg2
  fldl -8(%rsp)
  fyl2x
  fstpl -8(%rsp)
  movq -8(%rsp), %xmm0
  ret
