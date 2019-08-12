.section .text
.global ksyscall_setup
ksyscall_setup:
    xor %rdx, %rdx
    # MSR[SYSENTER_CS] = cs
    mov %cs, %rax
    mov $0x174, %rcx
    wrmsr
    # MSR[SYSENTER_ESP] = %esp
    mov %rdi, %rdx # higher part
    shr $32, %rdx
    mov %rdi, %rax # lower part
    mov $0x175, %rcx
    wrmsr
    # MSR[SYSENTER_EIP] = ksyscall_stub
    movabs $ksyscall_stub, %rdx # higher
    shr $32, %rdx
    movabs $ksyscall_stub, %rax # lower
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
    pusha64
    movabs $fxsave_region, %rax
    fxsave (%rax)
    # call the handler
    cld
    mov %rsp, %rdi
    call ksyscall_handler
    # return
    movabs $fxsave_region, %rax
    fxrstor (%rax)
    popa64
    mov %rcx, %rsp
    mov (%rsp), %rcx
    sysret

.global ksyscall_switch
ksyscall_switch:
    popa64
    movabs $fxsave_region, %rax
    fxrstor (%rax)
    add $8, %rsp # skip int_no
    iretq
