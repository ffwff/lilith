#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/gfx.h>
#include <sys/ioctl.h>
#include <syscalls.h>

#define LIBCANVAS_IMPLEMENTATION
#include <canvas.h>

#include "../.build/font8x8_basic.h"
#include "wm.h"

#define WIDTH 256
#define HEIGHT 256
#define FONT_WIDTH 8
#define FONT_HEIGHT 8

void canvas_ctx_draw_character(struct canvas_ctx *ctx, int xs, int ys, const char ch) {
    char *bitmap = font8x8_basic[ch];
    if(canvas_ctx_get_format(ctx) != LIBCANVAS_FORMAT_RGB24)
        return;
    unsigned long *data = (unsigned long *)canvas_ctx_get_surface(ctx);
    for (int x = 0; x < FONT_WIDTH; x++) {
        for (int y = 0; y < FONT_HEIGHT; y++) {
            if (bitmap[y] & 1 << x) {
                data[(ys + y) * canvas_ctx_get_width(ctx) + (xs + x)] = 0xffffffff;
            }
        }
    }
}

void canvas_ctx_draw_text(struct canvas_ctx *ctx, int xs, int ys, const char *s) {
    int x = xs, y = ys;
    while(*s) {
        canvas_ctx_draw_character(ctx, x, y, *s);
        x += FONT_WIDTH;
        s++;
    }
}

void window_redraw(struct canvas_ctx *ctx, int is_pressed) {
    if(is_pressed) {
        canvas_ctx_fill_rect(ctx, 0, 0, WIDTH, HEIGHT, canvas_color_rgb(0xff, 0xff, 0xff));
    } else {
        canvas_ctx_fill_rect(ctx, 0, 0, WIDTH, HEIGHT, canvas_color_rgb(0x32, 0x36, 0x39));
    }
    canvas_ctx_stroke_rect(ctx, 0, 0, WIDTH - 1, HEIGHT - 1, canvas_color_rgb(0x20, 0x21, 0x24));
}

int main(int argc, char **argv) {
    struct canvas_ctx *ctx = canvas_ctx_create(WIDTH, HEIGHT, LIBCANVAS_FORMAT_RGB24);
    window_redraw(ctx, 0);

    {
        const char *title = "Hello World";
        int x_title = (WIDTH - strlen(title) * FONT_WIDTH) / 2;
        canvas_ctx_draw_text(ctx, x_title, 10, title);
    }

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

    printf("initializing connection\n");
    int fb_fd = open("/fb0", 0);

    // window manager pipes
    int wm_control_fd = open("/pipes/wm", 0);
    int win_fd_m = -1, win_fd_s = -1;

    // connect to wm
    struct wm_connection_request conn_req = {
        .pid = getpid()
    };
    write(wm_control_fd, (char *)&conn_req, sizeof(struct wm_connection_request));
    while(1) {
        // try to poll for pipes
        char mpath[128] = { 0 };
        snprintf(mpath, sizeof(mpath), "/pipes/wm:%d:m", conn_req.pid);
        if(win_fd_m == -1) {
            if((win_fd_m = open(mpath, 0)) < 0) {
                goto await_conn;
            }
        }

        char spath[128] = { 0 };
        snprintf(spath, sizeof(spath), "/pipes/wm:%d:s", conn_req.pid);
        if(win_fd_s == -1) {
            if((win_fd_s = open(spath, 0)) < 0) {
                goto await_conn;
            }
        }

        if(win_fd_m != -1 && win_fd_s != -1) {
            break;
        }

    await_conn:
        usleep(1);
    }

    // event loop
    struct fbdev_bitblit sprite = {
        .target_buffer = GFX_BACK_BUFFER,
        .source = (unsigned long *)data,
        .x = 0,
        .y = 0,
        .width = WIDTH,
        .height = HEIGHT,
        .type = GFX_BITBLIT_SURFACE
    };

    struct wm_atom configure_atom = {
        .type = ATOM_CONFIGURE_MASK,
        .configure.event_mask = 0,
    };
    write(win_fd_s, (char *)&configure_atom, sizeof(configure_atom));

    struct wm_atom atom;
    int needs_redraw = 0;
    int retval = 0;
    while ((retval = read(win_fd_m, (char *)&atom, sizeof(struct wm_atom))) >= 0) {
        if(retval == 0)
            goto wait;
        struct wm_atom respond_atom = {
            .type = ATOM_RESPOND_TYPE,
            .respond.retval = 0,
        };
        switch (atom.type) {
            case ATOM_REDRAW_TYPE: {
                if (needs_redraw || atom.redraw.force_redraw) {
                    needs_redraw = 0;
                    ioctl(fb_fd, GFX_BITBLIT, &sprite);
                    respond_atom.respond.retval = 1;
                }
                write(win_fd_s, (char *)&respond_atom, sizeof(respond_atom));
                break;
            }
            case ATOM_MOVE_TYPE: {
                sprite.x = atom.move.x;
                sprite.y = atom.move.y;
                needs_redraw = 1;
                write(win_fd_s, (char *)&respond_atom, sizeof(respond_atom));
                break;
            }
            case ATOM_MOUSE_EVENT_TYPE: {
                if(atom.mouse_event.type == WM_MOUSE_PRESS) {
                    window_redraw(ctx, 1);
                } else {
                    window_redraw(ctx, 0);
                }
                needs_redraw = 1;
                write(win_fd_s, (char *)&respond_atom, sizeof(respond_atom));
                break;
            }
        }
    wait:
        waitfd(win_fd_m, (useconds_t)-1);
    }

    return 0;
}