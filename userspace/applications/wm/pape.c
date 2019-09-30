#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/gfx.h>
#include <sys/ioctl.h>
#include <sys/pipes.h>
#include <syscalls.h>
#include <time.h>

#include <wm/wmc.h>
#include <gui.h>
#include <png.h>

#define min(x,y) ((x)<(y)?(x):(y))

struct pape_state {
  int drawn_rows;
  int drawn;
  int width, height;
  png_structp png_ptr;
  png_infop info_ptr;
  unsigned char *row;
};

static void pape_init(struct pape_state *state) {
  state->drawn_rows = 0;
  state->drawn = 0;
  state->width = 0;
  state->height = 0;
  state->png_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING, 0, 0, 0);
  state->info_ptr = png_create_info_struct(state->png_ptr);
}

static void pape_init_img(struct pape_state *state, char *path) {
  FILE *fp = fopen(path, "r");
  if(!fp) return;

  png_structp png_ptr = state->png_ptr;
  png_infop info_ptr = state->info_ptr;
  
  png_init_io(png_ptr, fp);
  png_read_info(png_ptr, info_ptr);

  int width = png_get_image_width(png_ptr, info_ptr);
  int height = png_get_image_height(png_ptr, info_ptr);
  png_byte color_type = png_get_color_type(png_ptr, info_ptr);
  png_byte bit_depth = png_get_bit_depth(png_ptr, info_ptr);
  
  state->width = width;
  state->height = height;
  state->row = malloc(state->width * 4);
  
  // Read any color_type into 8bit depth, RGBA format.
  // See http://www.libpng.org/pub/png/libpng-manual.txt

  if(bit_depth == 16)
    png_set_strip_16(png_ptr);

  if(color_type == PNG_COLOR_TYPE_PALETTE)
    png_set_palette_to_rgb(png_ptr);

  // PNG_COLOR_TYPE_GRAY_ALPHA is always 8 or 16bit depth.
  if(color_type == PNG_COLOR_TYPE_GRAY && bit_depth < 8)
    png_set_expand_gray_1_2_4_to_8(png_ptr);

  if(png_get_valid(png_ptr, info_ptr, PNG_INFO_tRNS))
    png_set_tRNS_to_alpha(png_ptr);

  // These color_type don't have an alpha channel then fill it with 0xff.
  if(color_type == PNG_COLOR_TYPE_RGB ||
     color_type == PNG_COLOR_TYPE_GRAY ||
     color_type == PNG_COLOR_TYPE_PALETTE)
    png_set_filler(png_ptr, 0x0, PNG_FILLER_AFTER);

  if(color_type == PNG_COLOR_TYPE_GRAY ||
     color_type == PNG_COLOR_TYPE_GRAY_ALPHA)
    png_set_gray_to_rgb(png_ptr);

  png_set_bgr(png_ptr);

  png_read_update_info(png_ptr, info_ptr);
}

static void pape_redraw(struct g_application *app) {
  struct canvas_ctx *ctx = g_application_ctx(app);
  struct pape_state *state = (struct pape_state *)g_application_userdata(app);
  
  const int width = canvas_ctx_get_width(ctx);
  const int max_height = canvas_ctx_get_height(ctx);
  const int height = min(state->height, max_height);
  
  if(state->drawn_rows < height) {
    unsigned char *dst = canvas_ctx_get_surface(ctx);
    png_read_row(state->png_ptr, state->row, 0);
    memcpy(&dst[state->drawn_rows * width * 4], state->row, state->width * 4);
    state->drawn_rows++;
  } else if (state->drawn_rows == height) {
    g_application_clear_timeout(app);
    state->drawn = 1;
  }
}

static int window_redraw(struct g_application *app) {
  struct pape_state *state = (struct pape_state *)g_application_userdata(app);
  if(state->drawn) {
    state->drawn = 0;
    return 1;
  }
  return 0;
}

int main(int argc, char **argv) {
  struct pape_state state = { 0 };
  pape_init(&state);
  
  if(argc != 2) {
    printf("usage: %s wallpaper\n", argv[0]);
    return 1;
  }
  pape_init_img(&state, argv[1]);
  
  struct g_application *app = g_application_create(1, 1, 0);
  g_application_set_timeout_cb(app, 0, pape_redraw);
  g_application_set_event_mask(app, 0);
  g_application_set_window_properties(app, WM_PROPERTY_ROOT);
  g_application_set_userdata(app, &state);
  int width, height;
  g_application_screen_size(app, &width, &height);
  g_application_resize(app, width, height);
  
  g_application_set_redraw_cb(app, window_redraw);
  return g_application_run(app);
}
