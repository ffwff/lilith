#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/gfx.h>
#include <sys/ioctl.h>
#include <sys/pipes.h>
#include <syscalls.h>

#include <wm/wmc.h>
#include <gui.h>

static int bar_redraw(struct g_application *app) {
  struct canvas_ctx *ctx = g_application_ctx(app);

  // background
  canvas_ctx_fill_rect(ctx, 0, 0,
    g_application_width(app), g_application_height(app) - 1,
    canvas_color_rgb(0x22, 0x22, 0x22));

  // border
  canvas_ctx_fill_rect(ctx, 0, g_application_height(app) - 1,
    g_application_width(app), 1,
    canvas_color_rgb(0x8c, 0x8c, 0x8c));
  
  // text
  int text_y = (g_application_height(app) - FONT_HEIGHT) / 2;
  
  canvas_ctx_draw_text(ctx, 5, text_y, "lilith");
  
  char time_str[256];
  int time_len = snprintf(time_str, sizeof(time_str) - 1, "00:00:00 AM");
  int time_x = g_application_width(app) - time_len * FONT_WIDTH - 5;
  canvas_ctx_draw_text(ctx, time_x, text_y, time_str);

  return 1;
}

int main(int argc, char **argv) {
  struct g_application *app = g_application_create(1, 1);
  int width, height = 20;
  g_application_screen_size(app, &width, 0);
  g_application_resize(app, width, height);
  
  g_application_set_redraw_cb(app, bar_redraw);
  return g_application_run(app);
}
