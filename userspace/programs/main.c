#include "syscalls.h"

void _start() {
    unsigned long dev = spawn("/ata0/hello.bin");
    while(1) {}
}