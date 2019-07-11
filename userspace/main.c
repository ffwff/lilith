static unsigned long sysenter(unsigned long eax, unsigned long ebx) {
    unsigned long ret;
    asm volatile("sysenter" : "=a"(ret) : "a"(eax), "b"(ebx));
    return ret;
}

char *str = "Hello from userspace!";
void _start() {
    sysenter(0, (unsigned long)str);
    while(1);
}