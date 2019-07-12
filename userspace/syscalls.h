#pragma once

static unsigned long sysenter(unsigned long eax, unsigned long ebx, unsigned long edx) {
    unsigned long ret;
    __asm__ volatile(
        "push $1f\n"
        "mov %%esp, %%ecx\n"
        "sysenter\n"
        "1: add $4, %%esp\n"
        : "=a"(ret)
        : "a"(eax), "b"(ebx), "d"(edx)
        : "cc", "ecx", "edi", "esi", "memory");
    return ret;
}
