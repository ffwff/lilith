#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/gfx.h>
#include <sys/ioctl.h>
#include <syscalls.h>

#define LIBCANVAS_IMPLEMENTATION
#include <canvas.h>

#include "../.build/font8x8_basic.h"
#include "wmc.h"

#define WIDTH 256
#define HEIGHT 256
#define FONT_WIDTH 8
#define FONT_HEIGHT 8

int clamp(int d, int min, int max) {
    if(d < min) return min;
    if(d < max) return max;
    return d;
}

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

int is_coord_in_sprite(struct fbdev_bitblit *sprite, int x, int y) {
    if(x < 0) return 0;
    if(y < 0) return 0;
    return sprite->x <= x && x <= (sprite->x + sprite->width) && 
           sprite->y <= y && y <= (sprite->y + sprite->height);
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

    struct wmc_connection conn;
    wmc_connection_init(&conn);
    wmc_connection_obtain(&conn, ATOM_MOUSE_EVENT_MASK);

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

    int mouse_drag = 0;

    struct wm_atom atom;
    int needs_redraw = 0;
    int retval = 0;
    while ((retval = wmc_recv_atom(&conn, &atom)) >= 0) {
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
                wmc_send_atom(&conn, &respond_atom);
                break;
            }
            case ATOM_MOVE_TYPE: {
                sprite.x = atom.move.x;
                sprite.y = atom.move.y;
                needs_redraw = 1;
                wmc_send_atom(&conn, &respond_atom);
                break;
            }
            case ATOM_MOUSE_EVENT_TYPE: {
                if(atom.mouse_event.type == WM_MOUSE_PRESS &&
                   (is_coord_in_sprite(&sprite, atom.mouse_event.x, atom.mouse_event.y) ||
                   mouse_drag)) {
                    mouse_drag = 1;
                    sprite.x += atom.mouse_event.delta_x;
                    sprite.y += atom.mouse_event.delta_y;
                } else if (atom.mouse_event.type == WM_MOUSE_RELEASE && mouse_drag) {
                    mouse_drag = 0;
                }
                needs_redraw = 1;
                wmc_send_atom(&conn, &respond_atom);
                break;
            }
        }
    wait:
        wmc_wait_atom(&conn);
    }

    return 0;
}