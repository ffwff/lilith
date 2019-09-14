#include <stdio.h>
#include <string.h>
#include <syscalls.h>
#include <sys/ioctl.h>
#include <sys/pipes.h>

char *str = "hello";
char *str1 = "goodbye";

int main(int argc, char **argv) {
    int fd = create("/pipes/example");
    printf("sending \"%s\"...\n", str);

    ioctl(fd, PIPE_CONFIGURE, PIPE_WAIT_READ);

    write(fd, str, strlen(str));

    printf("spawning child\n");
    char *sargv[2] = { "pipechd", NULL };
    spawnv("pipechd", (char**)sargv);

    sleep(1);
    printf("sending \"%s\"...\n", str1);
    write(fd, str1, strlen(str1));

    return 0;
}
