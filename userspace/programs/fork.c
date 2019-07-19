#include <stdio.h>
#include <syscalls.h>

int main() {
    printf("fork\n");
    spawn("/ata0/main.bin");
}