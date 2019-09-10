#include <stdio.h>
#include <syscalls.h>

int main(int argc, char **argv) {
    int fd = open("/pipes/example", 0);
    char buf[1024] = {0};

    read(fd, buf, sizeof(buf) - 1);
    printf("recv: %s\n", buf);

    waitfd(fd, (useconds_t)-1);
    read(fd, buf, sizeof(buf) - 1);
    printf("recv: %s\n", buf);

    return 0;
}
