.section .text
.global ksyscall_setup
ksyscall_setup:
    xor %rdx, %rdx
    # MSR[SYSENTER_CS_MSR] = cs
    mov %cs, %rax
    mov $0x174, %rcx
    wrmsr
    # MSR[SYSENTER_ESP_MSR] = %esp
    mov %rsp, %rax
    mov $0x175, %rcx
    wrmsr
    # MSR[SYSENTER_EIP_MSR] = ksyscall_stub
    mov $ksyscall_stub, %rax
    mov $0x176, %rcx
    wrmsr
    ret

.global ksyscall_stub
.extern ksyscall_handler
ksyscall_stub:
    pusha64
    mov %rsp, %rdi
    call ksyscall_handler
    popa64
    mov %rcx, %rsp
    mov (%rsp), %rcx
    sysret
