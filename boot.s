.section .text

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

# code
.global _start
.global load_idt
.global load_gdt
.global read_eip
# start
.extern kmain            # this is defined in the c file

_start:
    cli
    mov $stack_top, %esp # set stack pointer
    ;push %ebx            # multiboot header location
    call kmain
    hlt 		         # halt the CPU

# stack
.section .bss
.align 16
stack_bottom:
.skip 16384 # 16 KiB
stack_top:
