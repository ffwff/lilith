#include <stdio.h>
#include <string.h>
#include <syscalls.h>

char *str = "hello";

int main(int argc, char **argv) {
    int fd = create("/pipes/example");
    printf("sending \"%s\"...\n", str);
    write(fd, str, strlen(str));

    printf("spawning child\n");
    char *sargv[2] = { "pipechd", NULL };
    spawnv("pipechd", (char**)sargv);

    sleep(1);
    printf("sending \"%s\"...\n", str);
    write(fd, str, strlen(str));

    return 0;
}
