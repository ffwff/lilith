# -- text

.section .text
.include "gdt.s"
.include "idt.s"
.include "paging.s"
.include "syscalls.s"
.include "user.s"

.section .bootstrap
.global _start
.extern kmain
_start:
    movabs $stack_top, %rsp
    # third bootstrap stage: jump to the higher mapped address
    movabs $_start_higher, %rcx
    jmp *%rcx
_start_higher:
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
.skip 16384 # 16 KiB
stack_top:
