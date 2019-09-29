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
  int close_x, close_y, close_w, close_h;
};

static int g_decoration_redraw(struct g_widget *widget) {
  g_widget_init_ctx(widget);

  struct g_decoration_data *data = (struct g_decoration_data *)widget->widget_data;
  
  // main widget
  if(data->widget) {
    if(data->widget->redraw_fn(data->widget))
      widget->needs_redraw = 1;
  }
  
  if(widget->needs_redraw) {
    canvas_ctx_fill_rect(widget->ctx, 0, 0,
      widget->width, widget->height,
      canvas_color_rgba(0x32, 0x36, 0x39, 0x7f));
    canvas_ctx_stroke_rect(widget->ctx, 0, 0,
      widget->width - 1, widget->height - 1,
      canvas_color_rgb(0xff, 0xff, 0xff));
      
    canvas_ctx_fill_rect(widget->ctx, data->close_x, data->close_y,
          data->close_w, data->close_h,
          canvas_color_rgb(0xff,0,0));
    
    if(data->title_ctx) {
      int x = (widget->width - canvas_ctx_get_width(data->title_ctx)) / 2;
      canvas_ctx_bitblit_mask(widget->ctx, data->title_ctx, x, 5, canvas_color_rgba(0,0,0,0));
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
  data->close_w = 15;
  data->close_h = 15;
  data->close_x = widget->width - data->close_w - 5;
  data->close_y = 0;
}

static int g_decoration_on_mouse(struct g_widget *widget, int type,
                                     unsigned int x, unsigned int y,
                                     int delta_x, int delta_y) {
  struct g_decoration_data *data = (struct g_decoration_data *)widget->widget_data;
  if(type == WM_MOUSE_PRESS) {
    if(data->close_x <= x && x <= (data->close_x + data->close_w) &&
       data->close_y <= y && y <= (data->close_y + data->close_h)) {
      g_application_close(widget->app);
      return 1;
    }
  }
  return 0;
}

struct g_decoration *g_decoration_create(struct g_application *app) {
  struct g_widget *decoration = calloc(1, sizeof(struct g_widget));
  if(!decoration) return 0;
  
  struct g_decoration_data *data = calloc(1, sizeof(struct g_decoration_data));
  if(!data) return 0;
  data->title = 0;
  data->widget = 0;
  
  decoration->app = app;
  decoration->widget_data = data;
  decoration->needs_redraw = 1;
  decoration->redraw_fn = g_decoration_redraw;
  decoration->resize_fn = g_decoration_resize;
  decoration->on_mouse_fn = g_decoration_on_mouse;
  return (struct g_decoration *)decoration;
}

void g_decoration_set_text(struct g_decoration *dec, const char *str) {
  struct g_widget *decoration = (struct g_widget *)dec;
  struct g_decoration_data *data = (struct g_decoration_data *)decoration->widget_data;

  if(data->title)
    free(data->title);
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
