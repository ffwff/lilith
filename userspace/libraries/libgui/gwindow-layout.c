#include <wm/wmc.h>
#include <canvas.h>
#include <stdlib.h>
#include <string.h>
#include <sys/gfx.h>

#include "gui.h"
#include "priv/gapplication-impl.h"
#include "priv/gwidget-impl.h"

struct g_window_layout_data {
  struct g_decoration *decoration;
  struct g_widget *main_widget;
};

static void g_window_layout_deinit(struct g_widget *widget) {
  struct g_window_layout_data *data = (struct g_window_layout_data *)widget->widget_data;
  free(data);
}

static void g_window_layout_redraw(struct g_widget *widget, struct g_application *app) {
  struct g_window_layout_data *data = (struct g_window_layout_data *)widget->widget_data;
  
  struct g_widget *decoration = (struct g_widget *)data->decoration;
  decoration->redraw_fn(decoration, app);
  canvas_ctx_bitblit(app->ctx, decoration->ctx, decoration->x, decoration->y);
  
  if(data->main_widget && data->main_widget->redraw_fn) {
    data->main_widget->redraw_fn(data->main_widget, app);
    canvas_ctx_bitblit(app->ctx, data->main_widget->ctx,
            data->main_widget->x, data->main_widget->y);
  }
}

static void g_window_layout_resize(struct g_widget *widget, int w, int h) {
  const int title_height = 20;
  struct g_window_layout_data *data = (struct g_window_layout_data *)widget->widget_data;
  g_widget_move_resize((struct g_widget *)data->decoration, 0, 0, w, h);
  if(data->main_widget) {
    g_widget_move_resize(data->main_widget, 1, title_height, w - 2, h - title_height - 1);
  }
}

static void g_window_layout_on_key(struct g_widget *widget, int ch) {
  struct g_window_layout_data *data = (struct g_window_layout_data *)widget->widget_data;
  if(data->main_widget && data->main_widget->on_key_fn) {
    data->main_widget->on_key_fn(data->main_widget, ch);
  }
}

struct g_window_layout *g_window_layout_create(struct g_widget *main_widget) {
  struct g_widget *layout = calloc(1, sizeof(struct g_widget));
  if(!layout) return 0;

  struct g_window_layout_data *data = calloc(1, sizeof(struct g_window_layout_data));
  if(!data) return 0;

  data->decoration = g_decoration_create();
  data->main_widget = main_widget;
  
  layout->z_index = -1;
  layout->widget_data = data;

  layout->deinit_fn = g_window_layout_deinit;
  layout->redraw_fn = g_window_layout_redraw;
  layout->resize_fn = g_window_layout_resize;
  layout->on_key_fn = g_window_layout_on_key;
  return (struct g_window_layout *)layout;
}

struct g_decoration *g_window_layout_decoration(struct g_window_layout *wlayout) {
  struct g_widget *widget = (struct g_widget *)wlayout;
  struct g_window_layout_data *data = (struct g_window_layout_data *)widget->widget_data;
  return (struct g_decoration *)data->decoration;
}

struct g_widget *g_window_layout_main_widget(struct g_window_layout *wlayout) {
  struct g_widget *widget = (struct g_widget *)wlayout;
  struct g_window_layout_data *data = (struct g_window_layout_data *)widget->widget_data;
  return data->main_widget;
}

void g_window_layout_set_main_widget(struct g_window_layout *wlayout, struct g_widget *main_widget) {
  struct g_widget *widget = (struct g_widget *)wlayout;
  struct g_window_layout_data *data = (struct g_window_layout_data *)widget->widget_data;
  data->main_widget = main_widget;
}
