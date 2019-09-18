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

  canvas_ctx_fill_rect(ctx, 0, 0,
    g_application_width(app), g_application_height(app),
    canvas_color_rgb(0x0, 0x0, 0x0));
  
  canvas_ctx_draw_text(ctx, 0, 0, "lilith");

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
