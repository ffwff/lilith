STACK_SIZE = 16384

# -- text

.section .text
.include "gdt.s"
.include "idt.s"
.include "syscalls.s"
.include "user.s"

.extern _BSS_START
.extern _BSS_END

.section .bootstrap
.global _start
.extern kmain
_start:
    movabs $stack_top, %rsp
    # third bootstrap stage: jump to the higher mapped address
    movabs $_start_higher, %rcx
    jmp *%rcx
_start_higher:
    # clear stack
    mov %rax, %r8
    cld
    movabs $stack_bottom, %rdi
    mov $STACK_SIZE, %rcx
    xor %rax, %rax
    rep stosb
    # clear bss
    movabs $_BSS_START, %rdi
    movabs $_BSS_END, %rcx
    sub %rdi, %rcx
    rep stosb
    mov %r8, %rax
_start_main:
    # call the main function
    mov %rax, %rdi
    mov %rbx, %rsi
    movabs $kmain, %rcx
    call *%rcx

# misc functions
.global no_opt
no_opt: ret

# -- data
.section .data
.global fxsave_region_ptr
.global stack_start
.global stack_end
fxsave_region_ptr:
    .quad fxsave_region
stack_start:
    .quad stack_bottom
stack_end:
    .quad stack_top
.align 16
fxsave_region:
    .skip 512
.include "../extern/fonts.s"

# -- stack
.section .stack
.skip 4096
.align 16
stack_bottom:
.skip STACK_SIZE
stack_top:
