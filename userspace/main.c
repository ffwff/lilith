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

static unsigned long write(unsigned long fd, const char *str) {
    return sysenter(2, fd, (unsigned long)str);
}

void _start() {
    unsigned long dev = open("vga");
    while(1) {
        char *s = itoa(getpid(), 10);
        write(dev, s);
    }
}