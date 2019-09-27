#include <stdio.h>
#include <string.h>
#include <syscalls.h>
#include <sys/ioctl.h>
#include <sys/pipes.h>

char *str = "hello";

int main(int argc, char **argv) {
    int fd = create("/tmp/test");
    write(fd, str, strlen(str));
    return 0;
}
