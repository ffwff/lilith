KERNEL_CODE_SELECTOR = 0x08

.section .text
.global kload_gdt
kload_gdt:
    lgdt (%rdi)
    # set the code segment and return
    push (%rsp)
    movq $KERNEL_CODE_SELECTOR, 8(%rsp)
    lretq
