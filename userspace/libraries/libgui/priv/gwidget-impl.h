#pragma once

typedef void (*g_widget_redraw_fn)(struct g_widget *widget,
                                  struct g_application *app);
typedef void (*g_widget_resize_fn)(struct g_widget *widget, int w, int h);
typedef void (*g_widget_deinit_fn)(struct g_widget *widget);
typedef void (*g_widget_on_key_fn)(struct g_widget *widget, int ch);

struct g_widget {
  unsigned int x, y, width, height;
  int z_index;
  struct canvas_ctx *ctx;
  
  void *widget_data;
  g_widget_deinit_fn deinit_fn;
  g_widget_resize_fn resize_fn;
  g_widget_redraw_fn redraw_fn;
  g_widget_on_key_fn on_key_fn;
};

static inline int g_widget_cmp_z_index(const void *a, const void *b) {
  return ((struct g_widget *)b)->z_index - ((struct g_widget *)a)->z_index;
}

void g_widget_init_ctx(struct g_widget *widget);
