DRIVER_CODE_SELECTOR = 0x29
DRIVER_DATA_SELECTOR = 0x31

.section .text
.global ksyscall_setup
ksyscall_setup:
    xor %rdx, %rdx
    # MSR[SYSENTER_CS] = cs
    mov %cs, %rax
    mov $0x174, %rcx
    wrmsr
    # MSR[SYSENTER_ESP] = %esp
    movabs $stack_top, %rdx # higher part
    mov %rdx, %rax # lower part
    shr $32, %rdx
    mov $0x175, %rcx
    wrmsr
    # MSR[SYSENTER_EIP] = ksyscall_stub
    movabs $ksyscall_stub, %rdx # higher
    shr $32, %rdx
    movabs $ksyscall_stub, %rax # lower
    mov $0x176, %rcx
    wrmsr
    # MSR[SYSCALL_STAR] =
    mov $0x001B0008, %edx
    mov $0x00000000, %eax
    mov $0xC0000081, %rcx
    wrmsr
    # MSR[SYSCALL_SFMASK]
    mov $0x00000200, %eax # disable interrupts
    mov $0xC0000084, %rcx
    wrmsr
    # MSR[SYSCALL_LSTAR] = %rdi
    movabs $ksyscall_stub_sc, %rdx # higher part
    mov %rdx, %rax # lower part
    shr $32, %rdx
    mov $0xC0000082, %rcx
    wrmsr
    ret

.extern ksyscall_handler

# sysenter instruction path
.global ksyscall_stub
ksyscall_stub:
    push $0 # rsp
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

# syscall instruction path
.global ksyscall_sc_ret_driver
ksyscall_stub_sc:
    # syscall doesn't set the rsp pointer for us (why amd?)
    # push rsp
    push %rax
    movabs $stack_top, %rax
    mov %rsp, -8(%rax)
    add $8, -8(%rax)
    pop %rax
    # rsp = stack_top
    movabs $stack_top - 8, %rsp # reserve space for %userrsp
    # push registers
    pusha64
    movabs $fxsave_region, %rax
    fxsave (%rax)
    # call the handler
    cld
    mov %rsp, %rdi
    call ksyscall_handler
ksyscall_sc_ret_driver:
    movabs $fxsave_region, %rax
    fxrstor (%rax)
    mov %rdi, %rsp
    add $8, %rsp
    popa64_no_ds
    pop %rdi # userrsp
    # return
    push $DRIVER_DATA_SELECTOR # ss
    push %rdi # userrsp
    push %r11 # rflags
    push $DRIVER_CODE_SELECTOR # cs
    push %rcx # rip
    iretq

.global ksyscall_switch
ksyscall_switch:
    mov %rdi, %rsp
    movabs $fxsave_region, %rax
    fxrstor (%rax)
    popa64
    add $8, %rsp # skip int_no
    iretq
