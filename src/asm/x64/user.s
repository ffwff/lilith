USER_DATA_SELECTOR = 0x23

.section .text
.global kswitch_usermode32
kswitch_usermode32:
    mov %rsp, %rbp
    mov $USER_DATA_SELECTOR, %rax
    mov %ax, %ds
    mov %ax, %fs
    mov %ax, %gs
    sti
    sysret
