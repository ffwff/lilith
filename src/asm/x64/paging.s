.section .text

.global kenable_paging
kenable_paging:
    mov %rdi, %cr3
    ret

.global kdisable_paging
kdisable_paging:
    ret
