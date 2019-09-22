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
unsigned int g_widget_x(struct g_widget *widget) {
  return widget->x;
}
unsigned int g_widget_y(struct g_widget *widget) {
  return widget->y;
}
unsigned int g_widget_width(struct g_widget *widget) {
  return widget->width;
}
unsigned int g_widget_height(struct g_widget *widget) {
  return widget->height;
}
int g_widget_z_index(struct g_widget *widget) {
  return widget->z_index;
}


// setters
void g_widget_set_x(struct g_widget *widget, unsigned int val) {
  widget->x = val;
}
void g_widget_set_y(struct g_widget *widget, unsigned int val) {
  widget->y = val;
}
void g_widget_set_width(struct g_widget *widget, unsigned val) {
  widget->width = val;
  if(widget->resize_fn) {
    widget->resize_fn(widget, widget->width, widget->height);
  }
}
void g_widget_set_height(struct g_widget *widget, unsigned val) {
  widget->height = val;
  if(widget->resize_fn) {
    widget->resize_fn(widget, widget->width, widget->height);
  }
}
void g_widget_set_z_index(struct g_widget *widget, int val) {
  widget->z_index = val;
}
void g_widget_move_resize(struct g_widget *widget, unsigned int x,
            unsigned int y, unsigned int width, unsigned int height) {
  widget->x = x;
  widget->y = y;
  widget->width = width;
  widget->height = height;
  if(widget->resize_fn) {
    widget->resize_fn(widget, widget->width, widget->height);
  }
}

