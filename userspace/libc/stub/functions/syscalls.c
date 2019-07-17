#include <string.h>

#include "syscalls.h"
#include "pdclib/_PDCLIB_glue.h"

int write(int fd, const void *str, size_t len) {
    struct {
        const void *s;
        size_t l;
    } buf = {0};
    buf.s = str;
    buf.l = len;
    return (int)sysenter(2, fd, (unsigned int)&buf);
}

int open(const char *device, int flags) {
    return (int)sysenter(0, (unsigned int)device, 0);
}

// process
void _exit() {
    sysenter(6, 0, 0);
}

int spawn(const char *file) {
    return sysenter(4, (unsigned long)file, 0);
}