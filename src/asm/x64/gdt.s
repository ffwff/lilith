KERNEL_CODE_SELECTOR = 0x08

.section .text
.global kload_gdt
kload_gdt:
    lgdt (%rdi)
    push $KERNEL_CODE_SELECTOR
    push $.flush_gdt
    lretq
.flush_gdt:
    ret

.global kload_tss
kload_tss:
    xor %rax, %rax
    ltr %ax
    ret
