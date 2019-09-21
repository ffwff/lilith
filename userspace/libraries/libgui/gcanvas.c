#include <wm/wmc.h>
#include <canvas.h>
#include <stdlib.h>
#include <string.h>

#include "gui.h"
#include "priv/gwidget-impl.h"

static void g_canvas_redraw_stub(struct g_widget *widget, struct g_application *app) {
}

struct g_canvas *g_canvas_create() {
  struct g_widget *canvas = calloc(1, sizeof(struct g_widget));
  canvas->redraw_fn = g_canvas_redraw_stub;
  return (struct g_canvas *)canvas;
}

struct canvas_ctx *g_canvas_ctx(struct g_canvas *canvas) {
  g_widget_init_ctx((struct g_widget *)canvas);
  return ((struct g_widget *)canvas)->ctx;
}

void g_canvas_set_redraw_fn(struct g_canvas *canvas, g_canvas_redraw_fn fn) {
  ((struct g_widget *)canvas)->redraw_fn = fn;
}
