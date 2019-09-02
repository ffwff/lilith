#include <stdio.h>
#include <syscalls.h>

int main(int argc, char **argv) {
    if(argc < 2) {
        printf("usage: %s seconds\n", argv[0]);
        return 1;
    }
    int secs = 0;
    sscanf(argv[1], "%d", &secs);
    usleep(secs * 1000000);
    return 0;
}