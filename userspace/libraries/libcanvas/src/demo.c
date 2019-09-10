#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"
#define LIBCANVAS_IMPLEMENTATION
#include "canvas.h"

#define WIDTH 640
#define HEIGHT 480

int main(int argc, char **argv) {
    struct canvas_ctx *ctx = canvas_ctx_create(WIDTH, HEIGHT, LIBCANVAS_FORMAT_ARGB32);
    canvas_ctx_fill_rect(ctx, 0, 0, 256, 256, canvas_color_rgb(0xf5, 0xf5, 0xf5));
    canvas_ctx_stroke_rect(ctx, 0, 0, 256, 256, canvas_color_rgb(0x93, 0x93, 0x93));
    // canvas_ctx_fill_circle(ctx, 60, 200, 60, canvas_color_rgb(0xff, 0xff, 0xff));
    stbi_write_bmp("file.bmp", WIDTH, HEIGHT, 4, canvas_ctx_get_surface(ctx));
    return 0;
}
