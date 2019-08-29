#include <stdio.h>
#include <syscalls.h>

int main(int argc, char **argv) {
    if(argc < 2) {
        printf("usage: %s filename\n", argv[0]);
        return 1;
    }
    create(argv[1]);
}