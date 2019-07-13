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

void _start() {
    unsigned long dev = spawn("/fat16/FAT16.BIN");
    while(1) {}
}