#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
    int d1 = 0, d2 = 0;
    sscanf("1,2", "%d,%d", &d1, &d2);
    printf("%d %d\n", d1, d2);
}