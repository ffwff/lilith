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

/* WM State */

struct wm_state;
struct wm_window;
struct wm_window_prog;
struct wm_window_sprite;

struct wm_state {
    int needs_redraw;
    int mouse_fd;
    struct wm_window *mouse_win; // weakref
    struct wm_window *windows;
    int nwindows;
};

#define WM_WINDOW_PROG   0
#define WM_WINDOW_SPRITE 1

struct wm_window_prog {
    int mfd, sfd;
};

struct wm_window_sprite {
    struct fbdev_bitblit sprite;
};

struct wm_window {
    int type;
    union {
        struct wm_window_prog prog;
        struct wm_window_sprite sprite;
    } as;
    size_t z_index;
};

/* IPC */

int win_write_and_wait(struct wm_window_prog *prog,
                       struct wm_atom *write_atom,
                       struct wm_atom *respond_atom) {
    write(prog->mfd, (char *)write_atom, sizeof(struct wm_atom));
    if (waitfd(prog->sfd, PACKET_TIMEOUT) < 0) {
        ftruncate(prog->mfd, 0);
        ftruncate(prog->sfd, 0);
        return 0;
    }
    // respond received
    return read(prog->sfd, (char *)respond_atom, sizeof(struct wm_atom));
}

/* IMPL */

struct wm_window *wm_add_window(struct wm_state *state) {
    state->windows = realloc(state->windows, state->nwindows + 1);
    return &state->windows[state->nwindows++];
}

struct wm_window *wm_add_win_prog(struct wm_state *state) {
    struct wm_window *win = wm_add_window(state);
    win->z_index = 1;
    win->type = WM_WINDOW_PROG;

    win->as.prog.mfd = create("/pipes/wm:sample:m");
    if(win->as.prog.mfd < 0) goto cleanup;

    win->as.prog.sfd = create("/pipes/wm:sample:s");
    if(win->as.prog.sfd < 0) goto cleanup;

    return win;
cleanup:
    // TODO
    return 0;
}

struct wm_window *wm_add_sprite(struct wm_state *state, struct wm_window_sprite *sprite) {
    struct wm_window *win = wm_add_window(state);
    win->z_index = 1;
    win->type = WM_WINDOW_SPRITE;
    win->as.sprite = *sprite;
    return win;
}

int wm_sort_windows_by_z_compar(const void *av, const void *bv) {
    const struct wm_window *a = av, *b = bv;
    if (a->z_index < b->z_index) return -1;
    else if(a->z_index == b->z_index) return 0;
    return 1;
}

void wm_sort_windows_by_z(struct wm_state *state) {
    qsort(state->windows, state->nwindows, sizeof(struct wm_window), wm_sort_windows_by_z_compar);
}

int main(int argc, char **argv) {
    int fb_fd = open("/fb0", 0);

    // setup
    struct winsize ws;
    ioctl(fb_fd, TIOCGWINSZ, &ws);

    struct wm_state wm = {0};

    // wallpaper
    {
        struct wm_window_sprite pape_spr = {
            .sprite = (struct fbdev_bitblit){
                .target_buffer = GFX_BACK_BUFFER,
                .source = (unsigned long*)0x000066cc,
                .x = 0,
                .y = 0,
                .width = ws.ws_col,
                .height = ws.ws_row,
                .type = GFX_BITBLIT_COLOR
            }
        };
        struct wm_window *win = wm_add_sprite(&wm, &pape_spr);
        win->z_index = 0;
    }

    // mouse
    {
        wm.mouse_fd = open("/mouse/raw", 0);

        struct wm_window_sprite mouse_spr = {
            .sprite = (struct fbdev_bitblit){
                .target_buffer = GFX_BACK_BUFFER,
                .source = NULL,
                .x = 100,
                .y = 100,
                .width = 0,
                .height = 0,
                .type = GFX_BITBLIT_SURFACE_ALPHA
            }
        };
        printf("loading cursor...\n");
        int w, h, n;
        mouse_spr.sprite.source = (unsigned long *)stbi_load(CURSOR_FILE, &w, &h, &n, channels);
        if (!mouse_spr.sprite.source) panic("can't load mouse_spr");
        mouse_spr.sprite.width = w;
        mouse_spr.sprite.height = h;
        filter_data_with_alpha(&mouse_spr.sprite);

        wm.mouse_win = wm_add_sprite(&wm, &mouse_spr);
        wm.mouse_win->z_index = (size_t)-1;
    }

    // sample win
    char *spawn_argv[] = {"canvwin", NULL};
    spawnv("canvwin", (char **)spawn_argv);
    wm_add_win_prog(&wm);

    wm_sort_windows_by_z(&wm);

    // disable console
    ioctl(STDOUT_FILENO, TIOCGSTATE, 0);

    // control pipe
    // int control_fd = create("/pipes/wm");

    wm.needs_redraw = 1;

    while(1) {
        {
            // mouse
            struct mouse_packet mouse_packet;
            read(wm.mouse_fd, (char *)&mouse_packet, sizeof(mouse_packet));

            unsigned int speed = __builtin_ffs(mouse_packet.x + mouse_packet.y);
            struct fbdev_bitblit *sprite = &wm.mouse_win->as.sprite.sprite;
            if (mouse_packet.x != 0) {
                // left = negative
                sprite->x += mouse_packet.x * speed;
                sprite->x = min(sprite->x, ws.ws_col);
                wm.needs_redraw = 1;
            }
            if (mouse_packet.y != 0) {
                // bottom = negative
                sprite->y -= mouse_packet.y * speed;
                sprite->y = min(sprite->y, ws.ws_col);
                wm.needs_redraw = 1;
            }
        }
        for (int i = 0; i < wm.nwindows; i++) {
            struct wm_window *win = &wm.windows[i];
            switch (win->type) {
                case WM_WINDOW_PROG: {
                    struct wm_atom redraw_atom = {
                        .type = ATOM_REDRAW_TYPE
                    };
                    struct wm_atom respond_atom;
                    int retval = win_write_and_wait(&win->as.prog, &redraw_atom, &respond_atom);

                    if (retval > 0) {
                        if (respond_atom.respond.retval)
                            wm.needs_redraw = 1;
                    }
                    break;
                }
                case WM_WINDOW_SPRITE: {
                    ioctl(fb_fd, GFX_BITBLIT, &win->as.sprite.sprite);
                    break;
                }
            }
        }
        ioctl(fb_fd, GFX_SWAPBUF, 0);
        //if (wm.needs_redraw || 1) {
        //    wm.needs_redraw = 0;
        //}
        // TODO: consistent frame rate
        usleep(FRAME_TICK);
    }

    return 0;
}