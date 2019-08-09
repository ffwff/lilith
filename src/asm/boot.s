.section .text
.include "paging.s"

.global _start
.extern kmain
_start:
    ret

.global kcpuint_end
kcpuint_end:
    ret

# -- data
.section .data
.global fxsave_region
.global stack_start
.global stack_end
fxsave_region:
    .long fxsave_region_asm
stack_start:
    .long stack_bottom
stack_end:
    .long stack_top
.align 16
fxsave_region_asm:
.skip 512

# -- stack
.section .stack
.skip 4096
.align 16
stack_bottom:
.skip 16384 # 16 KiB
stack_top:
