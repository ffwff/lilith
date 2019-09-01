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
#define CURSOR_FILE "/hd0/share/cursors/cursor.png"

int main(int argc, char **argv) {
    // open image
    int w,h,n;
    unsigned char *data = stbi_load(CURSOR_FILE, &w, &h, &n, channels);

    // draw it!
    int fb_fd = open("/fb0", 0);

    for (int i = 0; i < (w * h * 4); i += 4) {
        unsigned char r = data[i + 0];
        unsigned char g = data[i + 1];
        unsigned char b = data[i + 2];
        data[i + 0] = b;
        data[i + 1] = g;
        data[i + 2] = r;
        data[i + 3] = 0;
    }

    int mouse_fd = open("/mouse", 0);
    struct fbdev_bitblit mouse = {
        .source = (unsigned long*)data,
        .x = 100,
        .y = 100,
        .width = w,
        .height = h
    };

    struct winsize ws;
    ioctl(fb_fd, TIOCGWINSZ, &ws);

    while (1) {
        int mouse_dx, mouse_dy = 0;
        char mouse_buf[64] = {0};
        read(mouse_fd, mouse_buf, sizeof(mouse_buf) - 1);
        sscanf(mouse_buf, "%d,%d", &mouse_dx, &mouse_dy);

        printf("\033[1;2H%d,%d        \n", mouse_dx, mouse_dy);

        unsigned int speed = __builtin_ffs(mouse_dx + mouse_dy);
        if(mouse_dx != 0) {
            // left = negative
            mouse.x += mouse_dx * speed;
        }
        if(mouse_dy != 0) {
            mouse.y -= mouse_dy * speed;
        }
        if (mouse.x < 0) mouse.x = 0;
        if (mouse.x > ws.ws_col) mouse.x = ws.ws_col;
        if (mouse.y < 0) mouse.y = 0;
        if (mouse.y > ws.ws_row) mouse.y = ws.ws_row;
        ioctl(fb_fd, GFX_BITBLIT, &mouse);
    }

    // cleanup
    stbi_image_free(data);
    return 0;
}