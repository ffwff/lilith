#include <wm/wmc.h>
#include <canvas.h>
#include <sys/gfx.h>
#include <sys/ioctl.h>
#include "gui.h"
#include "priv/gwidget-impl.h"

void g_widget_init_ctx(struct g_widget *widget) {
  if(widget->ctx == 0) {
    widget->ctx = canvas_ctx_create(widget->width, widget->height,
                                    LIBCANVAS_FORMAT_ARGB32);
  }
}

// getters
struct canvas_ctx *g_widget_ctx(struct g_widget *widget) {
  return widget->ctx;
}
int g_widget_x(struct g_widget *widget) {
  return widget->x;
}
int g_widget_y(struct g_widget *widget) {
  return widget->y;
}
int g_widget_width(struct g_widget *widget) {
  return widget->width;
}
int g_widget_height(struct g_widget *widget) {
  return widget->height;
}
int g_widget_z_index(struct g_widget *widget) {
  return widget->z_index;
}

int g_widget_needs_redraw(struct g_widget *widget) {
  return widget->needs_redraw;
}


// setters
void g_widget_set_x(struct g_widget *widget, int val) {
  widget->x = val;
}
void g_widget_set_y(struct g_widget *widget, int val) {
  widget->y = val;
}
void g_widget_set_width(struct g_widget *widget, int val) {
  widget->width = val;
  if(widget->ctx) {
    canvas_ctx_resize_buffer(widget->ctx, val, widget->height);
  }
  if(widget->resize_fn) {
    widget->resize_fn(widget, widget->width, widget->height);
  }
}
void g_widget_set_height(struct g_widget *widget, int val) {
  widget->height = val;
  if(widget->ctx) {
    canvas_ctx_resize_buffer(widget->ctx, widget->width, val);
  }
  if(widget->resize_fn) {
    widget->resize_fn(widget, widget->width, widget->height);
  }
}
void g_widget_set_z_index(struct g_widget *widget, int val) {
  widget->z_index = val;
}

void g_widget_move(struct g_widget *widget, int x, int y) {
  widget->x = x;
  widget->y = y;
}

void g_widget_resize(struct g_widget *widget, int width, int height) {
  widget->width = width;
  widget->height = height;
  if(widget->ctx) {
    canvas_ctx_resize_buffer(widget->ctx, width, height);
  }
  if(widget->resize_fn) {
    widget->resize_fn(widget, widget->width, widget->height);
  }
}

void g_widget_move_resize(struct g_widget *widget, int x, int y,
                                          int width, int height) {
  g_widget_move(widget, x, y);
  g_widget_resize(widget, width, height);
}

void g_widget_set_needs_redraw(struct g_widget *widget, int needs_redraw) {
  widget->needs_redraw = needs_redraw;
}
