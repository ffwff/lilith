.section .text
.global kload_idt

kload_idt:
    lidt (%rdi)
    ret