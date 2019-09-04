#include <cairo/cairo.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/gfx.h>
#include <sys/ioctl.h>
#include <syscalls.h>

#include "wm.h"

#define WIDTH 512
#define HEIGHT 512

int main(int argc, char **argv) {
    cairo_surface_t *surface = cairo_image_surface_create(CAIRO_FORMAT_RGB24, WIDTH, HEIGHT);
    cairo_t *cr = cairo_create(surface);

    printf("initializing surface\n");
    cairo_pattern_t *pat = cairo_pattern_create_linear(0, 0, 0, HEIGHT);
    cairo_pattern_add_color_stop_rgb(pat, 0.0, 0.40, 0.17, 0.55);
    cairo_pattern_add_color_stop_rgb(pat, 1.0, 0.92, 0.12, 0.47);

    cairo_rectangle(cr, 0.0, 0.0, WIDTH, HEIGHT);
    cairo_set_source(cr, pat);
    cairo_fill(cr);

    cairo_select_font_face(cr, "cairo:sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
    cairo_set_font_size(cr, 90.0);
    cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
    cairo_show_text(cr, "Hello World");

    printf("initializing connection\n");
    int fb_fd = open("/fb0", 0);
    int sample_win_fd_m = open("/pipes/wm:sample:m", 0);
    int sample_win_fd_s = open("/pipes/wm:sample:s", 0);

    struct fbdev_bitblit sprite = {
        .target_buffer = GFX_BACK_BUFFER,
        .source = (unsigned long *)cairo_image_surface_get_data(surface),
        .x = 0,
        .y = 0,
        .width = WIDTH,
        .height = HEIGHT,
        .type = GFX_BITBLIT_SURFACE
    };

    struct wm_atom atom;
    int retval = 0;
    while ((retval = read(sample_win_fd_m, (char *)&atom, sizeof(atom))) >= 0) {
        if(retval == 0)
            goto wait;
        struct wm_atom respond_atom = {
            .type = ATOM_RESPOND_TYPE,
            .redraw.needs_redraw = 0,
        };
        switch (atom.type) {
            case ATOM_REDRAW_TYPE: {
                ioctl(fb_fd, GFX_BITBLIT, &sprite);
                write(sample_win_fd_s, (char *)&respond_atom, sizeof(respond_atom));
                break;
            }
            case ATOM_MOVE_TYPE: {
                sprite.x = atom.move.x;
                sprite.y = atom.move.y;
                respond_atom.redraw.needs_redraw = 1;
                write(sample_win_fd_s, (char *)&respond_atom, sizeof(respond_atom));
                break;
            }
        }
    wait:
        waitfd(sample_win_fd_m, (useconds_t)-1);
    }

    return 0;
}