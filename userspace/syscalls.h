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

// file io
static unsigned long open(const char *device) {
    return sysenter(0, (unsigned long)device, 0);
}

static unsigned long spawn(const char *device) {
    return sysenter(4, (unsigned long)device, 0);
}

static unsigned long write(unsigned long fd, const char *str, unsigned long len) {
    struct {
        const char *s;
        long l;
    } buf = {0};
    buf.s = str;
    buf.l = len;
    return sysenter(2, fd, (unsigned long)&buf);
}

static unsigned long read(unsigned long fd, const char *str, unsigned long len) {
    struct {
        const char *s;
        long l;
    } buf = {0};
    buf.s = str;
    buf.l = len;
    return sysenter(1, fd, (unsigned long)&buf);
}