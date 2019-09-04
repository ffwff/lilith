#include <cairo/cairo.h>
#include <stdio.h>
#include <sys/gfx.h>
#include <sys/ioctl.h>
#include <syscalls.h>
#include <math.h>

#define WIDTH 512
#define HEIGHT 512

int main(int argc, char **argv) {
    cairo_surface_t *surface = cairo_image_surface_create(CAIRO_FORMAT_RGB24, WIDTH, HEIGHT);
    cairo_t *cr = cairo_create(surface);

    cairo_pattern_t *pat = cairo_pattern_create_linear(0, 0, 0, HEIGHT);
    cairo_pattern_add_color_stop_rgb(pat, 0.0, 0.40, 0.17, 0.55);
    cairo_pattern_add_color_stop_rgb(pat, 1.0, 0.92, 0.12, 0.47);

    cairo_rectangle(cr, 0.0, 0.0, WIDTH, HEIGHT);
    cairo_set_source(cr, pat);
    cairo_fill(cr);

    cairo_select_font_face(cr, "monospace", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
    cairo_set_font_size(cr, 90.0);
    cairo_move_to(cr, 10.0, 135.0);
    cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
    cairo_show_text(cr, "Testing testing");

    struct fbdev_bitblit bitblit = {
        .target_buffer = GFX_FRONT_BUFFER,
        .source = (unsigned long*)cairo_image_surface_get_data(surface),
        .x = 0,
        .y = 0,
        .width = WIDTH,
        .height = HEIGHT,
        .type = GFX_BITBLIT_SURFACE
    };
    int fd = open("/fb0", 0);
    ioctl(fd, GFX_BITBLIT, &bitblit);

    return 0;
}
