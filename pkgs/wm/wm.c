#include <stdio.h>
#include <sys/ioctl.h>
#include <syscalls.h>
#include <cairo/cairo.h>

struct fbdev_bitblit {
    unsigned long *source;
    unsigned long x, y, width, height;
};

#define GFX_BITBLIT 3

int main(int argc, char const **argv)
{
    cairo_surface_t *surface = cairo_image_surface_create_from_png("/share/cursors/cursor.png");

    struct fbdev_bitblit bitblit = {
        .source = (unsigned long*)cairo_image_surface_get_data(surface),
        .x = 0,
        .y = 0,
        .width = cairo_image_surface_get_width(surface),
        .height = cairo_image_surface_get_height(surface)
    };
    int fd = open("/fb0", 0);
    ioctl(fd, GFX_BITBLIT, &bitblit);

    return 0;
}
