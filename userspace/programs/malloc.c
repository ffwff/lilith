#include <stdlib.h>
#include <stdio.h>
#include <string.h>

int main() {
    char *x = malloc(144);
    char *y = malloc(32);
    char *z = malloc(40);
    char *a = malloc(8);
    //strcpy(x, "Hello World");
    //printf("%s\n", x);
    free(x);
    free(y);
    free(z);
    free(a);
}