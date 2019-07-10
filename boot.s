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
# code
.global _start
.global load_idt
.global kload_gdt
.global kload_tss
.global kload_idt
.global kirq_stub
.global kenable_paging
.global kdisable_paging
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
    call kmain
    hlt 		         # halt the CPU

# -- utils
# gdt
kload_gdt:
    mov 4(%esp), %eax    # Get the pointer to the GDT, passed as a parameter.
    lgdt (%eax)          # Load the GDT pointer.
    mov %cr0, %eax
    or $1, %al           # Set Protected Mode flag
    mov %eax, %cr0
    ljmp $0x08, $.flush
.flush:
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
    iret
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

# -- stack
.section .stack
.skip 4096
.align 16
stack_bottom:
.skip 16384 # 16 KiB
stack_top:
