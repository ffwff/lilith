.section .multiboot
.set MBOOT_HEADER_MAGIC, 0x1BADB002
.set MBOOT_PAGE_ALIGN,   1 << 0
.set MBOOT_MEM_INFO,     1 << 1
.set MBOOT_VID_INFO,     1 << 2
.set MBOOT_HEADER_FLAGS, MBOOT_PAGE_ALIGN | MBOOT_MEM_INFO
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
.global _bootstrap_start
_bootstrap_start:
    # store multiboot
    mov %eax, (multiboot_magic)
    mov %ebx, (multiboot_header)
    # global descriptor table
    lgdt (gdt_table)
    # setup fxsr, xmmexcpt, pge, pae
    mov %cr4, %eax
    or $0x6A0, %ax
    mov %eax, %cr4
    # set the EFER flags
    mov $0xC0000080, %ecx
    rdmsr
    # enable long mode, syscall/sysret
    or $0x101, %eax
    wrmsr
    # enable paging
    mov $pml4, %eax
    mov %eax, %cr3
    mov %cr0, %eax
    or $0x80000000, %eax
    mov %eax, %cr0
    # restore multiboot
    mov (multiboot_magic), %eax
    mov (multiboot_header), %ebx
    # jump to second bootstrap stage
    ljmp $0x08, $kernel64

multiboot_magic: .long 0
multiboot_header: .long 0

.section .data
# global descriptor table
gdt_table:
    .word 3 * 8 - 1 # size
    .long gdt_null # offset
    .long 0

gdt_null:
    .quad 0

gdt_code:
    .word 0xFFFF # limit 0..15
    .word 0 # base 0..15
    .byte 0 # base 16.24
    .byte 0x9A # access
    .byte 0xAF # flags/attrs
    .byte 0 # base 24..31

gdt_data:
    .word 0xFFFF # limit 0..15
    .word 0 # base 0..15
    .byte 0 # base 16.24
    .byte 0x92 # access
    .byte 0xAF # flags/attrs
    .byte 0 # base 24..31

PAGE_PRESENT = 1 << 0
PAGE_WRITE   = 1 << 1
PAGE_2MB     = 1 << 7

# identity page the first 1GiB of physical memory
# pml4
.align 0x1000
pml4:
    .long pdpt + (PAGE_PRESENT | PAGE_WRITE) # 0x0
    .long 0
    .long pdpt + (PAGE_PRESENT | PAGE_WRITE) # 0x80_0000_0000
    .long 0
    .skip (256 - 2) * 8
    .long pdpt + (PAGE_PRESENT | PAGE_WRITE) # non-canonical identity mapping
    .long 0
pml4_len = . - pml4
    .skip 0x1000 - pml4_len
# pdpt
.align 0x1000
pdpt:
    .long pd + (PAGE_PRESENT | PAGE_WRITE)
    .long 0
pdpt_len = . - pdpt
    .skip 0x1000 - pdpt_len
# pd
.align 0x1000
pd:
    .quad 0x0 + (PAGE_PRESENT | PAGE_WRITE | PAGE_2MB)
pd_len = . - pd
    .skip 0x1000 - pd_len

.section .kernel64
.incbin "build/kernel64.bin"
