#include <string.h>

#include "syscalls.h"
#include "pdclib/_PDCLIB_glue.h"

int open(const char *device, int flags) {
    return (int)sysenter(0, (unsigned int)device, 0);
}

long write(int fd, const void *str, size_t len) {
    struct {
        const void *s;
        size_t l;
    } buf = {0};
    buf.s = str;
    buf.l = len;
    return (long)sysenter(2, fd, (unsigned int)&buf);
}

long read(int fd, char *str, unsigned long len) {
    struct {
        char *s;
        long l;
    } buf = {0};
    buf.s = str;
    buf.l = len;
    return (long)sysenter(1, fd, (unsigned long)&buf);
}

// process
void _exit() {
    sysenter(6, 0, 0);
}

long spawn(const char *file) {
    return sysenter(4, (unsigned long)file, 0);
}

long getcwd(char *str, unsigned long len) {
    struct {
        const char *s;
        long l;
    } buf = {0};
    buf.s = str;
    buf.l = len;
    return (long)sysenter(8, (unsigned long)&buf, 0);
}
