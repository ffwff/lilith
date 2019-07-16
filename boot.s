.section .multiboot
.set MBOOT_HEADER_MAGIC, 0x1BADB002
.set MBOOT_PAGE_ALIGN,   1 << 0
.set MBOOT_MEM_INFO,     1 << 1
.set MBOOT_HEADER_FLAGS, MBOOT_PAGE_ALIGN | MBOOT_MEM_INFO
.set MBOOT_CHECKSUM,     -(MBOOT_HEADER_MAGIC + MBOOT_HEADER_FLAGS)

# multiboot spec
.align 4
.long MBOOT_HEADER_MAGIC        # magic
.long MBOOT_HEADER_FLAGS        # flags
.long MBOOT_CHECKSUM            # checksum. m+f+c should be zero

.section .text
USER_STACK_TOP = 0xf0000000
USER_STACK_BOTTOM = 0x80000000
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
.global ksyscall_exit
# start
.extern kmain            # this is defined in the c file

_start:
    cli
    mov $stack_top, %esp # set stack pointer
    push %ebx            # multiboot header location
    push %eax            # multiboot magic value
    push $stack_bottom
    push $stack_top
    push $_DATA_END
    push $_DATA_START
    push $_TEXT_END
    push $_TEXT_START
    push $_KERNEL_END
    push $fxsave_region
    # setup sse
    mov %cr0, %eax
    and $0xFFFB, %ax
    or $0x2, %ax
    mov %eax, %cr0
    mov %cr4, %eax
    or $0x600, %ax
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
    # save sse state
    fxsave (fxsave_region)
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
    # call the handler
    cld
    call kirq_handler
ksyscall_exit: # NOTE: syscall_exit uses the same path to return to usermode
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
    fxrstor (fxsave_region)
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
# paging
kenable_paging:
    mov 4(%esp), %eax
    mov %eax, %cr3
    mov %cr0, %eax
    or $0x80000000, %eax # Enable paging!
    mov %eax, %cr0
    ret
kdisable_paging:
    mov %cr0, %eax
    and $0x7fffffff, %eax
    mov %eax, %cr0
    ret
# userspace
kswitch_usermode:
    mov $0x23, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    # data selector
    pushl $0x23
    # setup stack
    mov $USER_STACK_BOTTOM, %ebp
    pushl $USER_STACK_TOP
    # eflags
    pushf
    # enable interrupts
    pop %eax
    or $0x200, %eax
    push %eax
    # code selector
    pushl $0x1B
    # instruction pointer
    push %ecx
    iret
# syscalls
.extern ksyscall_handler
ksyscall_setup:
    xor %edx, %edx
    # MSR[SYSENTER_CS_MSR] = cs
    mov $0x1F, %eax
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
    push %ax
    mov $0x10, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    pop %ax
    # save sse state
    fxsave (fxsave_region)
    # call the handler
    pusha
    cld
    call ksyscall_handler
    popa
    add $4, %esp
    # load sse state
    fxrstor (fxsave_region)
    # use di because it is clobber value
    # segments
    mov $0x23, %di
    mov %di, %ds
    mov %di, %es
    mov %di, %fs
    mov %di, %gs
    # data selector
    pushl $0x23
    # setup stack
    pushl %ecx
    # eflags (enable interrupts)
    pushf
    pop %edi
    or $0x200, %edi
    push %edi
    # code selector
    pushl $0x1B
    # instruction pointer
    push (%ecx)
    iret

.section .data
.align 16
fxsave_region:
.skip 512

# -- stack
.section .stack
.skip 4096
.align 16
stack_bottom:
.skip 16384 # 16 KiB
stack_top:
