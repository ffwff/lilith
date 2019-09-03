#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/gfx.h>
#include <sys/ioctl.h>
#include <sys/mouse.h>
#include <syscalls.h>

#include "wm.h"

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

static void filter_data_with_alpha(struct fbdev_bitblit *sprite) {
    unsigned char *data = (unsigned char *)sprite->source;
    for (unsigned long i = 0; i < (sprite->width * sprite->height * 4); i += 4) {
        unsigned char r = data[i + 0];
        unsigned char g = data[i + 1];
        unsigned char b = data[i + 2];
        unsigned char a = data[i + 3];
        // premultiply by alpha / 0xff
        data[i + 0] = (b * a) >> 8;
        data[i + 1] = (g * a) >> 8;
        data[i + 2] = (r * a) >> 8;
    }
}

static void panic(const char *s) {
    puts(s);
    exit(1);
}

#define min(x, y) ((x)<(y)?(x):(y))

#define PACKET_TIMEOUT 1000000
#define FRAME_TICK  1000000/60

int main(int argc, char **argv) {
    int w, h, n;
    int fb_fd = open("/fb0", 0);

    // setup
    struct winsize ws;
    ioctl(fb_fd, TIOCGWINSZ, &ws);

    // wallpaper
    #if 0
    struct fbdev_bitblit pape_spr = {
        .target_buffer = GFX_BACK_BUFFER,
        .source = NULL,
        .x = 0,
        .y = 0,
        .width = 0,
        .height = 0,
        .type = GFX_BITBLIT_SURFACE
    };
    printf("loading wallpaper...\n");
    pape_spr.source = (unsigned long*)stbi_load(WALLPAPER_FILE, &w, &h, &n, channels);
    pape_spr.width = w;
    pape_spr.height = h;
    if(!pape_spr.source) panic("can't load pape_spr");
    filter_data(&pape_spr);
    #else
    struct fbdev_bitblit pape_spr = {
        .target_buffer = GFX_BACK_BUFFER,
        .source = (unsigned long*)0x000066cc,
        .x = 0,
        .y = 0,
        .width = ws.ws_col,
        .height = ws.ws_row,
        .type = GFX_BITBLIT_COLOR
    };
    #endif

    // mouse
    int mouse_fd = open("/mouse/raw", 0);
    struct fbdev_bitblit mouse_spr = {
        .target_buffer = GFX_BACK_BUFFER,
        .source = NULL,
        .x = 100,
        .y = 100,
        .width = 0,
        .height = 0,
        .type = GFX_BITBLIT_SURFACE_ALPHA
    };
    printf("loading cursor...\n");
    mouse_spr.source = (unsigned long *)stbi_load(CURSOR_FILE, &w, &h, &n, channels);
    mouse_spr.width = w;
    mouse_spr.height = h;
    if (!mouse_spr.source) panic("can't load mouse_spr");
    filter_data_with_alpha(&mouse_spr);

    // disable console
    ioctl(STDOUT_FILENO, TIOCGSTATE, 0);

    // sample win
    int sample_win_fd_m = create("/pipes/wm:sample:m");
    int sample_win_fd_s = create("/pipes/wm:sample:s");
    char *spawn_argv[] = { "cairowin", NULL };
    spawnv("cairowin", (char**)spawn_argv);

    int needs_redraw = 1;

    while (1) {
        // wallpaper
        ioctl(fb_fd, GFX_BITBLIT, &pape_spr);

        // windows
        if (needs_redraw) {
            ftruncate(sample_win_fd_m, 0);
            ftruncate(sample_win_fd_s, 0);

            struct wm_atom atom = {
                .type = ATOM_REDRAW_TYPE
            };
            write(sample_win_fd_m, (char *)&atom, sizeof(atom));
            waitfd(sample_win_fd_s, PACKET_TIMEOUT);

            struct wm_atom respond_atom;
            read(sample_win_fd_s, (char *)&respond_atom, sizeof(respond_atom));
            if (respond_atom.redraw.needs_redraw)
                needs_redraw = 1;
        }

        // mouse
        struct mouse_packet mouse_packet;
        read(mouse_fd, (char *)&mouse_packet, sizeof(mouse_packet));

        unsigned int speed = __builtin_ffs(mouse_packet.x + mouse_packet.y);
        if(mouse_packet.x != 0) {
            // left = negative
            mouse_spr.x += mouse_packet.x * speed;
            mouse_spr.x = min(mouse_spr.x, ws.ws_col);
            needs_redraw = 1;
        }
        if (mouse_packet.y != 0) {
            // bottom = negative
            mouse_spr.y -= mouse_packet.y * speed;
            mouse_spr.y = min(mouse_spr.y, ws.ws_row);
            needs_redraw = 1;
        }
        if ((mouse_packet.attr_byte & MOUSE_ATTR_LEFT_BTN) != 0) {
            ftruncate(sample_win_fd_m, 0);
            ftruncate(sample_win_fd_s, 0);

            struct wm_atom atom = {
                .type = ATOM_MOVE_TYPE,
                .move = (struct wm_atom_move){
                    .x = mouse_spr.x,
                    .y = mouse_spr.y,
                }
            };
            write(sample_win_fd_m, (char *)&atom, sizeof(atom));
            waitfd(sample_win_fd_s, PACKET_TIMEOUT);

            struct wm_atom respond_atom;
            read(sample_win_fd_s, (char *)&respond_atom, sizeof(respond_atom));
            if (respond_atom.redraw.needs_redraw) {
                needs_redraw = 1;
            }
        }
        if(needs_redraw)
            ioctl(fb_fd, GFX_BITBLIT, &mouse_spr);

        if (needs_redraw) {
            ioctl(fb_fd, GFX_SWAPBUF, 0);
        }
        // TODO: consistent frame rate
        usleep(FRAME_TICK);
    }

    // cleanup
    return 0;
}