#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <syscalls.h>

#define STB_IMAGE_IMPLEMENTATION
#define STBI_ASSERT(x)
#include "../.build/stb_image.h"

double ldexp(double x, int exp) {
    abort();
    return 0.0;
}

const int channels = 4;

int main(int argc, char **argv) {
    if (argc < 2) {
        printf("usage: %s filename\n", argv[0]);
        return 1;
    }

    // open image
    int w,h,n;
    unsigned char *data = stbi_load(argv[1], &w, &h, &n, channels);
    if(data == 0) {
        printf("%s: unable to open file %s\n", argv[0], argv[1]);
        return 1;
    }

    // draw it!
    int fd = open("/fb0", 0);

    for (int i = 0; i < (w * h * 4); i += 4) {
        unsigned char r = data[i + 0];
        unsigned char g = data[i + 1];
        unsigned char b = data[i + 2];
        data[i + 0] = b;
        data[i + 1] = g;
        data[i + 2] = r;
        data[i + 3] = 0;
    }
    struct fbdev_bitblit bitblit = {
        .target_buffer = GFX_FRONT_BUFFER,
        .source = (unsigned long*)data,
        .x = 0,
        .y = 0,
        .width = w,
        .height = h
    };
    ioctl(fd, GFX_BITBLIT, &bitblit);

    // cleanup
    stbi_image_free(data);
    return 0;
}