#include <wm/wmc.h>
#include <canvas.h>
#include <stdlib.h>
#include <string.h>

#include "gui.h"
#include "priv/gwidget-impl.h"
// #include "priv/gdecoration-impl.h"

struct g_decoration_data {
  char *title;
  struct canvas_ctx *title_ctx;
};

static void g_decoration_redraw(struct g_widget *widget, struct g_application *app) {
  g_widget_init_ctx(widget);
  
  canvas_ctx_fill_rect(widget->ctx, 0, 0,
    widget->width, widget->height,
    canvas_color_rgb(0x32, 0x36, 0x39));
  canvas_ctx_stroke_rect(widget->ctx, 0, 0,
    widget->width - 1, widget->height - 1,
    canvas_color_rgb(0x20, 0x21, 0x24));
  
  struct g_decoration_data *data = (struct g_decoration_data *)widget->widget_data;
  if(data->title_ctx) {
    int x = (widget->width - canvas_ctx_get_width(data->title_ctx)) / 2;
    canvas_ctx_bitblit(widget->ctx, data->title_ctx, x, 5);
  }
}

struct g_decoration *g_decoration_create() {
  struct g_widget *decoration = calloc(1, sizeof(struct g_widget));
  if(!decoration) return 0;
  
  struct g_decoration_data *data = calloc(1, sizeof(struct g_decoration_data));
  if(!data) return 0;
  data->title = 0;
  
  decoration->widget_data = data;
  decoration->redraw_fn = g_decoration_redraw;
  return (struct g_decoration *)decoration;
}

void g_decoration_set_text(struct g_decoration *dec, const char *str) {
  struct g_widget *decoration = (struct g_widget *)dec;
  struct g_decoration_data *data = (struct g_decoration_data *)decoration->widget_data;
  data->title = strdup(str);
  int length = strlen(str);
  int width = length * FONT_WIDTH; // TODO
  if(data->title_ctx) {
    // TODO
    abort();
  } else {
    data->title_ctx = canvas_ctx_create(width, FONT_HEIGHT,
              LIBCANVAS_FORMAT_RGB24);
    for(int i = 0; i < length; i++) {
      canvas_ctx_draw_character(data->title_ctx, i * FONT_WIDTH, 0, str[i]);
    }
  }
}
