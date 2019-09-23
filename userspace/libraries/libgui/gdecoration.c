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
  struct g_widget *widget;
};

static int g_decoration_redraw(struct g_widget *widget, struct g_application *app) {
  g_widget_init_ctx(widget);

  struct g_decoration_data *data = (struct g_decoration_data *)widget->widget_data;
  
  // main widget
  if(data->widget) {
    if(data->widget->redraw_fn(data->widget, app))
      widget->needs_redraw = 1;
  }
  
  if(widget->needs_redraw) {
    canvas_ctx_fill_rect(widget->ctx, 0, 0,
      widget->width, widget->height,
      canvas_color_rgba(0x32, 0x36, 0x39, 0x7f));
    canvas_ctx_stroke_rect(widget->ctx, 0, 0,
      widget->width - 1, widget->height - 1,
      canvas_color_rgb(0xff, 0xff, 0xff));
    
    if(data->title_ctx) {
      int x = (widget->width - canvas_ctx_get_width(data->title_ctx)) / 2;
      canvas_ctx_bitblit(widget->ctx, data->title_ctx, x, 5);
    }
    
    if(data->widget) {
      int y = FONT_HEIGHT + 8;
      if(data->widget->ctx)
        canvas_ctx_bitblit(widget->ctx, data->widget->ctx, 5, y);
    }
    
    widget->needs_redraw = 0;
    return 1;
  }
  
  return 0;
}

static void g_decoration_resize(struct g_widget *widget, int width, int height) {
  widget->needs_redraw = 1;
  struct g_decoration_data *data = (struct g_decoration_data *)widget->widget_data;
  if(data->widget) {
    data->widget->needs_redraw = 1;
  }
}

struct g_decoration *g_decoration_create() {
  struct g_widget *decoration = calloc(1, sizeof(struct g_widget));
  if(!decoration) return 0;
  
  struct g_decoration_data *data = calloc(1, sizeof(struct g_decoration_data));
  if(!data) return 0;
  data->title = 0;
  data->widget = 0;
  
  decoration->widget_data = data;
  decoration->needs_redraw = 1;
  decoration->redraw_fn = g_decoration_redraw;
  decoration->resize_fn = g_decoration_resize;
  return (struct g_decoration *)decoration;
}

void g_decoration_set_text(struct g_decoration *dec, const char *str) {
  struct g_widget *decoration = (struct g_widget *)dec;
  struct g_decoration_data *data = (struct g_decoration_data *)decoration->widget_data;
  data->title = strdup(str);
  int length = strlen(str);
  int width = length * FONT_WIDTH;
  if(data->title_ctx && canvas_ctx_get_width(data->title_ctx) != width) {
    canvas_ctx_resize_buffer(data->title_ctx, width, FONT_HEIGHT);
  } else {
    data->title_ctx = canvas_ctx_create(width, FONT_HEIGHT,
              LIBCANVAS_FORMAT_RGB24);
  }
  for(int i = 0; i < length; i++) {
    canvas_ctx_draw_character(data->title_ctx, i * FONT_WIDTH, 0, str[i]);
  }
}

// widget
struct g_widget *g_decoration_widget(struct g_decoration *dec) {
  struct g_widget *decoration = (struct g_widget *)dec;
  struct g_decoration_data *data = (struct g_decoration_data *)decoration->widget_data;
  return data->widget;
}

void g_decoration_set_widget(struct g_decoration *dec, struct g_widget *widget) {
  struct g_widget *decoration = (struct g_widget *)dec;
  struct g_decoration_data *data = (struct g_decoration_data *)decoration->widget_data;
  data->widget = widget;
}

int g_decoration_height(struct g_decoration *dec) {
  struct g_widget *decoration = (struct g_widget *)dec;
  struct g_decoration_data *data = (struct g_decoration_data *)decoration->widget_data;
  int height = FONT_HEIGHT + 5;
  if(data->widget) {
    height += data->widget->height;
  }
  return height;
}
