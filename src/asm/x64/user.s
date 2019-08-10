USER_CODE_SELECTOR = 0x1b

.section .text
.global kswitch_usermode32
kswitch_usermode32:
    mov %rsp, %rbp
    mov $USER_CODE_SELECTOR, %rax
    mov %ax, %ds
    mov %ax, %fs
    mov %ax, %gs
    sysret
