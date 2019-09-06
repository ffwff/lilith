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

#define PACKET_TIMEOUT 1000000/30
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
    return read(prog->sfd, (char *)respond_atom, sizeof(respond_atom));
}

/* IMPL */

struct wm_window *wm_add_window(struct wm_state *state) {
    state->windows = realloc(state->windows, state->nwindows + 1);
    return &state->windows[state->nwindows++];
}

struct wm_window *wm_add_win_prog(struct wm_state *state) {
    struct wm_window *win = wm_add_window(state);
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
    win->type = WM_WINDOW_SPRITE;
    win->as.sprite = *sprite;
    return win;
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
        wm_add_sprite(&wm, &pape_spr);
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
        wm_add_sprite(&wm, &mouse_spr);
    }

    // disable console
    ioctl(STDOUT_FILENO, TIOCGSTATE, 0);

    // control pipe
    // int control_fd = create("/pipes/wm");

    // sample win
    char *spawn_argv[] = { "canvwin", NULL };
    spawnv("canvwin", (char**)spawn_argv);

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
                        if (respond_atom.redraw.needs_redraw)
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
        if (wm.needs_redraw) {
            ioctl(fb_fd, GFX_SWAPBUF, 0);
            wm.needs_redraw = 0;
        }
        // TODO: consistent frame rate
        usleep(FRAME_TICK);
    }

#if 0
    int needs_redraw = 1;
    int retval;

    while (1) {
        // wallpaper
        ioctl(fb_fd, GFX_BITBLIT, &pape_spr);

        // windows
        if (needs_redraw) {
            struct wm_atom redraw_atom = {
                .type = ATOM_REDRAW_TYPE
            };
            struct wm_atom respond_atom;
            retval = wm_write_and_wait(sample_win_fd_m, sample_win_fd_s, &redraw_atom, &respond_atom);

            if(retval > 0) {
                if (respond_atom.redraw.needs_redraw)
                    needs_redraw = 1;
            }
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
#endif

    return 0;
}