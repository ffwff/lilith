#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
    int d = 0;
    printf("read: [%d]\n", sscanf("1", "%d", &d));
    printf("%d\n", d);
}