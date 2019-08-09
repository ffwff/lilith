.section .text
pusha64:
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
    # ret
    mov 112(%rsp), %rcx
    jmp *(%rcx)
