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
#define WALLPAPER_FILE "/hd0/share/papes/yuki.jpg"

static void filter_data(struct fbdev_bitblit *sprite) {
    unsigned char *data = (unsigned char *)sprite->source;
    for (unsigned long i = 0; i < (sprite->width * sprite->height * 4); i += 4) {
        unsigned char r = data[i + 0];
        unsigned char g = data[i + 1];
        unsigned char b = data[i + 2];
        data[i + 0] = b;
        data[i + 1] = g;
        data[i + 2] = r;
        data[i + 3] = 0;
    }
}

static void panic(const char *s) {
    puts(s);
    exit(1);
}

#define min(x, y) ((x)<(y)?(x):(y))

int main(int argc, char **argv) {
    int w, h, n;
    int fb_fd = open("/fb0", 0);

    // setup
    struct winsize ws;
    ioctl(fb_fd, TIOCGWINSZ, &ws);

    // wallpaper
    struct fbdev_bitblit pape_spr = {
        .target_buffer = GFX_BACK_BUFFER,
        .source = NULL,
        .x = 0,
        .y = 0,
        .width = 0,
        .height = 0
    };
    pape_spr.source = (unsigned long*)stbi_load(WALLPAPER_FILE, &w, &h, &n, channels);
    pape_spr.width = w;
    pape_spr.height = h;
    if(!pape_spr.source) panic("can't load pape_spr");
    filter_data(&pape_spr);

    // mouse
    int mouse_fd = open("/mouse", 0);
    struct fbdev_bitblit mouse_spr = {
        .target_buffer = GFX_BACK_BUFFER,
        .source = NULL,
        .x = 100,
        .y = 100,
        .width = 0,
        .height = 0
    };
    mouse_spr.source = (unsigned long *)stbi_load(CURSOR_FILE, &w, &h, &n, channels);
    mouse_spr.width = w;
    mouse_spr.height = h;
    if (!mouse_spr.source) panic("can't load mouse_spr");
    filter_data(&mouse_spr);

    while (1) {
        // wallpaper
        ioctl(fb_fd, GFX_BITBLIT, &pape_spr);

        // mouse
        int mouse_dx, mouse_dy = 0;
        char mouse_buf[64] = {0};
        read(mouse_fd, mouse_buf, sizeof(mouse_buf) - 1);
        sscanf(mouse_buf, "%d,%d", &mouse_dx, &mouse_dy);

        unsigned int speed = __builtin_ffs(mouse_dx + mouse_dy);
        if(mouse_dx != 0) {
            // left = negative
            mouse_spr.x += mouse_dx * speed;
        }
        if(mouse_dy != 0) {
            mouse_spr.y -= mouse_dy * speed;
        }
        mouse_spr.x = min(mouse_spr.x, ws.ws_col);
        mouse_spr.y = min(mouse_spr.y, ws.ws_row);
        ioctl(fb_fd, GFX_BITBLIT, &mouse_spr);

        ioctl(fb_fd, GFX_SWAPBUF, 0);
    }

    // cleanup
    return 0;
}