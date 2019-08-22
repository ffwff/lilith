#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <syscalls.h>

#define STB_IMAGE_IMPLEMENTATION
#define STBI_ASSERT(x)
#include "../build/stb_image.h"

double ldexp(double x, int exp) {
    abort();
    return 0.0;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        printf("usage: %s filename\n", argv[0]);
        return 1;
    }
    int x,y,n;
    unsigned char *data = stbi_load(argv[1], &x, &y, &n, 0);
    if(data == 0) {
        printf("%s: unable to open file %s\n", argv[0], argv[1]);
        return 1;
    }
    stbi_image_free(data);
    return 0;
}