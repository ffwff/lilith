.section .text

.macro kcpuex_handler_err number
.global kcpuex\number
kcpuex\number:
    push $\number
    jmp kcpuex_stub
.endm

.macro kcpuex_handler_no_err number
.global kcpuex\number
kcpuex\number:
    push $0
    push $\number
    jmp kcpuex_stub
.endm

kcpuex_handler_no_err 0
kcpuex_handler_no_err 1
kcpuex_handler_no_err 2
kcpuex_handler_no_err 3
kcpuex_handler_no_err 4
kcpuex_handler_no_err 5
kcpuex_handler_no_err 6
kcpuex_handler_no_err 7
kcpuex_handler_err    8
kcpuex_handler_no_err 9
kcpuex_handler_err    10
kcpuex_handler_err    11
kcpuex_handler_err    12
kcpuex_handler_err    13
kcpuex_handler_err    14
kcpuex_handler_no_err 15
kcpuex_handler_no_err 16
kcpuex_handler_no_err 17
kcpuex_handler_no_err 18
kcpuex_handler_no_err 19
kcpuex_handler_no_err 20
kcpuex_handler_no_err 21
kcpuex_handler_no_err 22
kcpuex_handler_no_err 23
kcpuex_handler_no_err 24
kcpuex_handler_no_err 25
kcpuex_handler_no_err 26
kcpuex_handler_no_err 27
kcpuex_handler_no_err 28
kcpuex_handler_no_err 29
kcpuex_handler_no_err 30
kcpuex_handler_no_err 31
