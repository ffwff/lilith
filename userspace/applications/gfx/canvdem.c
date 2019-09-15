#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/gfx.h>
#include <sys/ioctl.h>
#include <syscalls.h>

#include <canvas.h>
#include <font8x8_basic.h>

#define WIDTH 512
#define HEIGHT 512

void canvas_ctx_draw_character(struct canvas_ctx *ctx, int xs, int ys, char ch) {
    char *bitmap = font8x8_basic[ch];
    if(canvas_ctx_get_format(ctx) != LIBCANVAS_FORMAT_RGB24)
        return;
    uint32_t *data = canvas_ctx_get_surface(ctx);
    for (int x = 0; x < 8; x++) {
        for (int y = 0; y < 8; y++) {
            if (bitmap[y] & 1 << x) {
                data[(ys + y) * canvas_ctx_get_width(ctx) + (xs + x)] = 0xff000000;
            }
        }
    }
}

void canvas_ctx_draw_text(struct canvas_ctx *ctx, int xs, int ys, char *s) {
    int x = xs, y = ys;
    while(*s) {
        canvas_ctx_draw_character(ctx, x, y, *s);
        x += 8;
        s++;
    }
}

int main(int argc, char **argv) {
    struct canvas_ctx *ctx = canvas_ctx_create(WIDTH, HEIGHT, LIBCANVAS_FORMAT_RGB24);
    canvas_ctx_fill_rect(ctx, 0, 0, 100, 100, canvas_color_rgb(0x0, 0xff, 0xff));

    canvas_ctx_draw_text(ctx, 0, 0, "Hello World");

    // draw it!
    int fd = open("/fb0", O_RDWR);

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
