.section .text
.include "cpuex.s"

PUSHA_SIZE = 14 * 8
INT_FRAME_SIZE = PUSHA_SIZE + 7 * 8

.macro pusha64
    # gp registers
    push %rax
    push %rbx
    push %rcx
    push %rdx
    push %r8
    push %r9
    push %r10
    push %r11
    push %r12
    push %r13
    push %r14
    push %r15
    # scan registers
    push %rsi
    push %rdi
.endm

.macro popa64
    # scan registers
    pop %rdi
    pop %rsi
    # gp registers
    pop %r15
    pop %r14
    pop %r13
    pop %r12
    pop %r11
    pop %r10
    pop %r9
    pop %r8
    pop %rdx
    pop %rcx
    pop %rbx
    pop %rax
.endm

.global kload_idt
kload_idt:
    lidt (%rdi)
    ret

.global kcpuex_stub
.extern kcpuex_handler
kcpuex_stub:
    pusha64
    mov %rsp, %rdi
    call kcpuex_handler
