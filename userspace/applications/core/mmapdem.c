#include <stdio.h>
#include <string.h>
#include <syscalls.h>

int main(int argc, char **argv) {
    int fd = create("/tmp/x");
    ftruncate(fd, 0x1000);
    int fd1 = create("/tmp/y");
    ftruncate(fd1, 0x1000);
    char *ptr = mmap(fd, (size_t)-1);
    printf("%p\n", ptr);
    strcpy(ptr, "Hello World\n");
    ftruncate(fd1, 0x1000);
    char *ptr1 = mmap(fd1, (size_t)-1);
    printf("%p\n", ptr1);
    strcpy(ptr1, "Goodbye World\n");
    return 0;
}
