#include <stdio.h>

int main() {
    printf("hello world\n");
    spawn("/ata0/main.bin");
    while(1) {}
}