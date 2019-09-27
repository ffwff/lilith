#include <stdio.h>
#include <string.h>
#include <syscalls.h>

int main(int argc, char **argv) {
    int fd = open("/fb0", O_RDWR);
    void *ptr = mmap(fd, (size_t)-1);
    printf("%p\n", ptr);
    return 0;
}
