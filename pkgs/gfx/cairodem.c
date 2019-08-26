#include <stdio.h>
#include <sys/ioctl.h>
#include <syscalls.h>
#include <cairo/cairo.h>

struct fbdev_bitblit {
    unsigned long *source;
    unsigned long x, y, width, height;
};

#define FB_BITBLIT 3

#define WIDTH 512
#define HEIGHT 512

int main(int argc, char const **argv)
{
    cairo_surface_t *surface = cairo_image_surface_create(CAIRO_FORMAT_RGB24, WIDTH, HEIGHT);
    cairo_t *cr = cairo_create(surface);
    cairo_rectangle(cr, 0.0, 0.0, WIDTH, HEIGHT);
    cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
    cairo_fill(cr);

    struct fbdev_bitblit bitblit = {
        .source = (unsigned long*)cairo_image_surface_get_data(surface),
        .x = 0,
        .y = 0,
        .width = WIDTH,
        .height = HEIGHT
    };
    int fd = open("/fb0", 0, 0);
    ioctl(fd, FB_BITBLIT, &bitblit);

    return 0;
}
