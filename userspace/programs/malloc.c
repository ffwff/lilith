#include <stdlib.h>
#include <stdio.h>
#include <string.h>

int main() {
    char *x = malloc(100);
    strcpy(x, "Hello World");
    printf("%s\n", x);
    free(x);
}