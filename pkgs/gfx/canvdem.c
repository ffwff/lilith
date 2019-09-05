#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/gfx.h>
#include <sys/ioctl.h>
#include <syscalls.h>

#define LIBCANVAS_IMPLEMENTATION
#include <canvas.h>

#define WIDTH 512
#define HEIGHT 512

int main(int argc, char **argv) {
    struct canvas_ctx *ctx = canvas_ctx_create(WIDTH, HEIGHT, LIBCANVAS_FORMAT_RGB24);
    canvas_ctx_fill_rect(ctx, 0, 0, 100, 100, canvas_color_rgb(0x0, 0xff, 0xff));

    // draw it!
    int fd = open("/fb0", 0);

    unsigned char *data = canvas_ctx_get_surface(ctx);
    for (int i = 0; i < (WIDTH * HEIGHT * 4); i += 4) {
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
        .source = data,
        .x = 0,
        .y = 0,
        .width = WIDTH,
        .height = HEIGHT,
        .type = GFX_BITBLIT_SURFACE
    };
    ioctl(fd, GFX_BITBLIT, &bitblit);

    // cleanup
    return 0;
}