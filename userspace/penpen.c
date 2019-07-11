#include "syscalls.h"

static void write(const char *s) {
    sysenter(0, (unsigned long)s);
}

void _start() {
    while (1) {
        write("Quack quack");
    }

}