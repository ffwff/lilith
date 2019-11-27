.global log
.type log,@function
log:
	fldln2
  movq %xmm0, -8(%rsp)
	fldl -8(%rsp)
	fyl2x
  fstp -8(%rsp)
  movq -8(%rsp), %xmm0
	ret

