#include "syscalls.h"

void _start() {
    unsigned long dev = open("/fat16/TEST.TXT");
    char buf[256];
    read(dev, buf, 256);
    while(1) {}
}