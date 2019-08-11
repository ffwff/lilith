.section .text
.global ksyscall_setup
ksyscall_setup:
    xor %rdx, %rdx
    # MSR[SYSENTER_CS] = cs
    mov %cs, %rax
    mov $0x174, %rcx
    wrmsr
    # MSR[SYSENTER_ESP] = %esp
    mov %rsp, %rax
    mov $0x175, %rcx
    wrmsr
    # MSR[SYSENTER_EIP] = ksyscall_stub
    mov $ksyscall_stub, %rax
    mov $0x176, %rcx
    wrmsr
    # MSR[SYSCALL_STAR] =
    mov $0x001B0000, %edx
    mov $0x00000000, %eax
    mov $0xC0000081, %rcx
    wrmsr
    ret

.global ksyscall_stub
.extern ksyscall_handler
ksyscall_stub:
    fxsave (fxsave_region)
    pusha64
    # call the handler
    mov %rsp, %rdi
    call ksyscall_handler
    # return
    popa64
    fxrstor (fxsave_region)
    mov %rcx, %rsp
    mov (%rsp), %rcx
    sysret

.global ksyscall_switch
ksyscall_switch:
    popa64
    fxrstor (fxsave_region)
    add $8, %rsp # skip int_no
    iretq
