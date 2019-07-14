#include "syscalls.h"

char buf[256] = {0};
void _start() {
    unsigned long dev = open("/ata0/TEST.TXT");
    read(dev, buf, 256);
    unsigned long vga = open("/vga");
    write(vga, buf, 256);
    while(1) {}
}