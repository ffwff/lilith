#include <stdio.h>
#include <cairo/cairo.h>

int main(int argc, char const **argv)
{
    cairo_surface_t *surface = cairo_image_surface_create(CAIRO_FORMAT_RGB24, 512, 512);
    cairo_t *cr = cairo_create(surface);
    cairo_rectangle(cr, 0.0, 0.0, 512.0, 512.0);
    cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
    cairo_fill(cr);
    printf("%x\n", cairo_image_surface_get_data(surface)[0]);
    return 0;

}
