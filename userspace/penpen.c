static unsigned long sysenter(unsigned long eax, unsigned long ebx) {
    unsigned long ret;
    __asm__ volatile(
        "push $1f\n"
        "mov %%esp, %%ecx\n"
        "sysenter\n"
        "1: add $4, %%esp\n" : "=a"(ret) : "a"(eax), "b"(ebx));
    return ret;
}

static void write(const char *s) {
    sysenter(0, (unsigned long)s);
}

void _start() {
    write("Quack quack");
    while(1);
}