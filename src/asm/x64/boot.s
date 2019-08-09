# -- text

.section .text
.include "gdt.s"
.include "idt.s"
.include "paging.s"

.section .bootstrap
.global _start
.extern kmain
_start:
    mov $stack_top, %rsp # set stack pointer
    mov %rax, %rdi
    mov %rbx, %rsi
    call kmain

.global kcpuint_end
kcpuint_end:
    ret

# -- data
.section .data
.global fxsave_region
.global stack_start
.global stack_end
fxsave_region:
    .quad fxsave_region_asm
stack_start:
    .quad stack_bottom
stack_end:
    .quad stack_top
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
