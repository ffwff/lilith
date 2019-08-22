#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <syscalls.h>

#define STB_IMAGE_IMPLEMENTATION
#define STBI_ASSERT(x)
#include "../build/stb_image.h"

double ldexp(double x, int exp) {
    abort();
    return 0.0;
}

const int channels = 3;

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
    int fd = open("/fb0", 0, 0);

    struct winsize ws;
    if (ioctl(fd, TIOCGWINSZ, &ws) < 0) {
        printf("%s: unable to get screen dimensions\n", argv[0]);
        return 1;
    }

    for(int y = 0; y < h; y++) {
        for(int x = 0; x < w; x++) {
            int offset = (y * w + x) * channels;
            unsigned char r = data[offset + 0];
            unsigned char g = data[offset + 1];
            unsigned char b = data[offset + 2];
            unsigned long color = r << 16 | g << 8 | b;

            int fd_offset = y * ws.ws_col + x;
            lseek(fd, fd_offset * 4, SEEK_SET);
            write(fd, &color, 4);
        }
    }

    // cleanup
    stbi_image_free(data);
    return 0;
}