#include <wm/wmc.h>
#include <canvas.h>
#include <stdlib.h>

#include "gui.h"
#include "priv/gwidget-impl.h"
// #include "priv/gdecoration-impl.h"

static int g_decoration_redraw(struct g_widget *widget, struct g_application *app) {
  g_widget_init_ctx(widget);
  
  canvas_ctx_fill_rect(widget->ctx, 0, 0,
    widget->width, widget->height,
    canvas_color_rgb(0x32, 0x36, 0x39));
  canvas_ctx_stroke_rect(widget->ctx, 0, 0,
    widget->width - 1, widget->height - 1,
    canvas_color_rgb(0x20, 0x21, 0x24));
  
  return 1;
}

struct g_decoration *g_decoration_create() {
  struct g_widget *decoration = calloc(1, sizeof(struct g_widget));
  if(!decoration) return 0;

  decoration->redraw_fn = g_decoration_redraw;
  return (struct g_decoration *)decoration;
}
