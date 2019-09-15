#include <wm/wmc.h>
#include <canvas.h>
#include <stdlib.h>
#include <sys/gfx.h>
#include <sys/ioctl.h>
#include "gui.h"
#include "priv/gwidget-impl.h"

static void g_termbox_deinit(struct g_widget *widget) {
  
}

static int g_termbox_redraw(struct g_widget *widget, struct g_application *app) {
  canvas_ctx_fill_rect(widget->ctx, 0, 0,
        widget->width, widget->height,
        canvas_color_rgb(0, 0, 0));
  return 0;
}

struct g_termbox *g_termbox_create() {
  struct g_widget *termbox = calloc(1, sizeof(struct g_widget));
  termbox->deinit_fn = g_termbox_deinit;
  termbox->redraw_fn = g_termbox_redraw;
  return (struct g_termbox *)termbox;
}
