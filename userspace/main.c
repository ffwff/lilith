#include "syscalls.h"

static unsigned long getpid() {
    return sysenter(3, 0, 0);
}

static char *itoa(unsigned int num, int base) {
    static char buff[33];
    char *ptr;
    ptr = &buff[sizeof(buff) - 1];
    *ptr = '\0';
    do {
        *--ptr = "0123456789abcdef"[num % base];
        num /= base;
    } while (num != 0);
    return ptr;
}

//
static unsigned long open(const char *device) {
    return sysenter(0, (unsigned long)device, 0);
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

//

void _start() {
    // unsigned long dev = open("/vga//x");
    unsigned long dev = open("/vga");
    //unsigned long dev = open("/vga/x");
    while(1) {
        write(dev, "ABC", 1);
    }
}