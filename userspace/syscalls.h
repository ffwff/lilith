#pragma once

static unsigned long sysenter(unsigned long eax, unsigned long ebx) {
    unsigned long ret;
    __asm__ volatile(
        "mov %%esp, %%ecx\n"
        "mov $1f, %%edx\n"
        "sysenter\n"
        "1:\n"
        : "=a"(ret)
        : "a"(eax), "b"(ebx)
        : "cc", "ecx", "edx", "edi", "esi", "memory");
    return ret;
}
