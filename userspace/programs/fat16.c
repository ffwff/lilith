#include "syscalls.h"

void _start() {
    unsigned long dev = open("/ata0/test.txt");
    char buf[256] = {0};
    read(dev, buf, 256);
    unsigned long vga = open("/vga");
    write(vga, buf, 256);
    while(1) {}
}