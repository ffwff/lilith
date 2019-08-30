unsigned long sysenter(unsigned long eax, unsigned long ebx, unsigned long edx) {
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

extern int _open(char *device, int flags);
int open(char *device, int flags, ...) {
    return _open(device, flags);
}