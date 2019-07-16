#include "syscalls.h"

void _start() {
    unsigned long vga = open("/vga");
    char s[] = "Hello World";
    write(vga, s, sizeof(s));
    exit();
}