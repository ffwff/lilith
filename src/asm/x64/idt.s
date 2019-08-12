.section .text
.include "cpuex.s"

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
    # segment registers
    mov %ds, %ax
    push %rax
.endm

.macro popa64
    # segment registers
    pop %rax
    mov %ax, %ds
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
    # TODO: return
    popa64
    iret

# irq
.altmacro
.macro kirq_handler_label number
.global kirq\number
kirq\number:
    push $\number
    jmp kirq_stub
.endm
.set i, 0
.rept 16
    kirq_handler_label %i
    .set i, i+1
.endr

.extern kirq_handler
kirq_stub:
    pusha64
    movabs $fxsave_region, %rax
    fxsave (%rax)
    # call the handler
    cld
    mov %rsp, %rdi
    call kirq_handler
    # return
    movabs $fxsave_region, %rax
    fxrstor (%rax)
    popa64
    add $8, %rsp # skip int_no
    iretq

