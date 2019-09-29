#pragma once

typedef int (*g_widget_redraw_fn)(struct g_widget *widget);
typedef void (*g_widget_resize_fn)(struct g_widget *widget, int w, int h);
typedef void (*g_widget_deinit_fn)(struct g_widget *widget);
typedef void (*g_widget_on_key_fn)(struct g_widget *widget, int ch);
typedef int (*g_widget_on_mouse_fn)(struct g_widget *widget, int type,
                                    unsigned int x, unsigned int y,
                                    int delta_x, int delta_y);

struct g_widget {
  unsigned int x, y, width, height;
  int z_index;
  struct canvas_ctx *ctx;
  
  int needs_redraw;
  struct g_application *app;
  
  void *widget_data;
  g_widget_deinit_fn deinit_fn;
  g_widget_resize_fn resize_fn;
  g_widget_redraw_fn redraw_fn;
  g_widget_on_key_fn on_key_fn;
  g_widget_on_mouse_fn on_mouse_fn;
};

static inline int g_widget_cmp_z_index(const void *a, const void *b) {
  return ((struct g_widget *)b)->z_index - ((struct g_widget *)a)->z_index;
}

static inline int is_coord_in_widget(struct g_widget *widget,
                                unsigned int x, unsigned int y) {
  return widget->x <= x && x <= (widget->x + widget->width) && 
         widget->y <= y && y <= (widget->y + widget->height);
}

void g_widget_init_ctx(struct g_widget *widget);

#define TRANSLATE_ABS_COORDS_TO_WIDGET(widget) \
  unsigned int tx = x - widget->x; \
  unsigned int ty = y - widget->y;
