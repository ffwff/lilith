#include <stdio.h>
#include <string.h>
#include <syscalls.h>

int main(int argc, char **argv) {
    int fd = create("/tmp/x");
    ftruncate(fd, 0x384000);
    char *ptr = mmap(fd, (size_t)-1);
    printf("%p\n", ptr);
    return 0;
}
