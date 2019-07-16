#include <string.h>

#include "syscalls.h"
#include "pdclib/_PDCLIB_glue.h"

long write(int fd, const void *str, size_t len) {
    struct {
        const void *s;
        size_t l;
    } buf = {0};
    buf.s = str;
    buf.l = len;
    return (long)sysenter(2, fd, (unsigned long)&buf);
}