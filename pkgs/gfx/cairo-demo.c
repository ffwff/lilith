#include <cairo/cairo.h>

int main(int argc, char const **argv)
{
    cairo_surface_t *surface = cairo_image_surface_create(CAIRO_FORMAT_RGB24, 640, 480);
    return 0;
}
