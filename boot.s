.section .multiboot
.set MBOOT_HEADER_MAGIC, 0x1BADB002
.set MBOOT_PAGE_ALIGN,   1 << 0
.set MBOOT_MEM_INFO,     1 << 1
.set MBOOT_VID_INFO,     1 << 2
.set MBOOT_HEADER_FLAGS, MBOOT_PAGE_ALIGN | MBOOT_MEM_INFO | MBOOT_VID_INFO
.set MBOOT_CHECKSUM,     -(MBOOT_HEADER_MAGIC + MBOOT_HEADER_FLAGS)

# multiboot spec
.align 4
.long MBOOT_HEADER_MAGIC        # magic
.long MBOOT_HEADER_FLAGS        # flags
.long MBOOT_CHECKSUM            # checksum. m+f+c should be zero
.long 0, 0, 0, 0, 0
.long 0 # 0 = set graphics mode
.long 1024, 768, 32 # Width, height, depth

.section .text
KERNEL_DATA_SELECTOR = 0x10
USER_DATA_SELECTOR = 0x23
# code
.global _start
.global load_idt
.global kload_gdt
.global kload_tss
.global kload_idt
.global kirq_stub
.global kenable_paging
.global kdisable_paging
.global ksyscall_setup
.global kswitch_usermode
.global ksyscall_stub
.global kcpuint_end
# start
.extern kmain
.altmacro

_start:
    cli
    mov $stack_top, %esp # set stack pointer
    push %ebx            # multiboot header location
    push %eax            # multiboot magic value
    # setup sse
    mov %cr0, %eax
    and $0xFFFB, %ax
    or $0x2, %ax
    mov %eax, %cr0
    # setup fxsr, xmmexcpt, pge, pae
    mov %cr4, %eax
    or $0x6A0, %ax
    mov %eax, %cr4
    # run the function
    call kmain
    hlt                 # halt the CPU

# -- utils
# gdt
kload_gdt:
    mov 4(%esp), %eax    # Get the pointer to the GDT, passed as a parameter.
    lgdt (%eax)          # Load the GDT pointer.
    mov %cr0, %eax
    or $1, %al           # Set Protected Mode flag
    mov %eax, %cr0
    ljmp $0x08, $.flush_gdt
.flush_gdt:
    ret
# tss
kload_tss:
    mov $0x2b, %ax
    ltr %ax
    ret
# idt
kload_idt:
    mov 4(%esp), %eax    # Get the pointer to the IDT, passed as a parameter.
    lidt (%eax)          # Load the IDT pointer.
    ret
# irq stub
kirq_stub:
.macro interrupt_start
    # save sse state
    fxsave (fxsave_region_asm)
    # registers
    pusha
    # save data segment descriptor
    mov %ds, %ax
    push %ax
    # load kernel segment descriptor
    mov $0x10, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
.endm
    interrupt_start
    # call the handler
    cld
    call kirq_handler
    # reload original data segment selector
    pop %bx
    mov %bx, %ds
    mov %bx, %es
    mov %bx, %fs
    mov %bx, %gs
    # return
    popa
    add $4, %esp
    # reload sse state
    fxrstor (fxsave_region_asm)
    iret
# irq
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
# exception
kcpuex_stub:
    interrupt_start
    # call the handler
    cld
    call kcpuex_handler
    # reload original data segment selector
    pop %bx
    mov %bx, %ds
    mov %bx, %es
    mov %bx, %fs
    mov %bx, %gs
    # return
    popa
    add $8, %esp
    # reload sse state
    fxrstor (fxsave_region_asm)
    iret

.macro kcpuex_handler_err number
.global kcpuex\number
kcpuex\number:
    push $\number
    jmp kcpuex_stub
.endm

.macro kcpuex_handler_no_err number
.global kcpuex\number
kcpuex\number:
    push $0
    push $\number
    jmp kcpuex_stub
.endm

kcpuex_handler_no_err 0
kcpuex_handler_no_err 1
kcpuex_handler_no_err 2
kcpuex_handler_no_err 3
kcpuex_handler_no_err 4
kcpuex_handler_no_err 5
kcpuex_handler_no_err 6
kcpuex_handler_no_err 7
kcpuex_handler_err    8
kcpuex_handler_no_err 9
kcpuex_handler_err    10
kcpuex_handler_err    11
kcpuex_handler_err    12
kcpuex_handler_err    13
kcpuex_handler_err    14
kcpuex_handler_no_err 15
kcpuex_handler_no_err 16
kcpuex_handler_no_err 17
kcpuex_handler_no_err 18
kcpuex_handler_no_err 19
kcpuex_handler_no_err 20
kcpuex_handler_no_err 21
kcpuex_handler_no_err 22
kcpuex_handler_no_err 23
kcpuex_handler_no_err 24
kcpuex_handler_no_err 25
kcpuex_handler_no_err 26
kcpuex_handler_no_err 27
kcpuex_handler_no_err 28
kcpuex_handler_no_err 29
kcpuex_handler_no_err 30
kcpuex_handler_no_err 31

# paging
kenable_paging:
    # switch to long mode through setting EFER
    mov $0xC0000080, %ecx
    rdmsr
    or $0x100, %eax
    wrmsr
    # Enable paging
    mov 4(%esp), %eax
    mov %eax, %cr3
    mov %cr0, %eax
    or $0x80000000, %eax
    mov %eax, %cr0
    ret
kdisable_paging:
    mov %cr0, %eax
    and $0x7fffffff, %eax
    mov %eax, %cr0
    ret
# userspace
kswitch_usermode:
    mov $USER_DATA_SELECTOR, %eax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    # ecx contains esp
    # edx contains instruction pointer
    sysexit
# syscalls
.extern ksyscall_handler
ksyscall_setup:
    xor %edx, %edx
    # MSR[SYSENTER_CS_MSR] = cs
    mov %cs, %eax
    mov $0x174, %ecx
    wrmsr
    # MSR[SYSENTER_ESP_MSR] = %esp
    mov %esp, %eax
    mov $0x175, %ecx
    wrmsr
    # MSR[SYSENTER_EIP_MSR] = ksyscall_stub
    mov $ksyscall_stub, %eax
    mov $0x176, %ecx
    wrmsr
    ret
ksyscall_stub:
    # load kernel segment descriptor
    mov $KERNEL_DATA_SELECTOR, %di
    mov %di, %ds
    mov %di, %es
    mov %di, %fs
    mov %di, %gs
    # save sse state
    fxsave (fxsave_region_asm)
    # call the handler
    pusha
    cld
    call ksyscall_handler
    popa
    add $4, %esp
    # load sse state
    fxrstor (fxsave_region_asm)
    # segment selectors
    mov $USER_DATA_SELECTOR, %di
    mov %di, %ds
    mov %di, %es
    mov %di, %fs
    mov %di, %gs
    mov (%ecx), %edx
    sysexit
kcpuint_end:
    # reload original data segment selector
    pop %bx
    mov %bx, %ds
    mov %bx, %es
    mov %bx, %fs
    mov %bx, %gs
    # return
    popa
    add $4, %esp
    # reload sse state
    fxrstor (fxsave_region_asm)
    iret
# misc
.global kidle_loop
kidle_loop:
    hlt
    jmp kidle_loop

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
