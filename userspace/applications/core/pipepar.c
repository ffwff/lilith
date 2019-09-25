#include <stdio.h>
#include <string.h>
#include <syscalls.h>
#include <sys/ioctl.h>
#include <sys/pipes.h>

char *str = "hello";
char *str1 = "goodbye";

int main(int argc, char **argv) {
    int fd = mkfpipe("example", PIPE_WAIT_READ | PIPE_M_WR | PIPE_G_RD);
    if(fd < 0) {
        printf("unable to open pipe!\n");
        return 1;
    }
    
    printf("sending \"%s\"...\n", str);
    write(fd, str, strlen(str));

    printf("spawning child\n");
    char *sargv[2] = { "pipechd", NULL };
    pid_t pid = spawnv("pipechd", (char**)sargv);

    sleep(1);
    printf("sending \"%s\"...\n", str1);
    write(fd, str1, strlen(str1));
    
    waitpid(pid, 0, 0);
    remove("/pipes/example");

    return 0;
}
