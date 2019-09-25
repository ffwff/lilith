#pragma once

struct g_canvas;

typedef int (*g_canvas_redraw_fn)(struct g_widget *widget,
                                  struct g_application *app);
typedef void (*g_canvas_on_mouse_fn)(struct g_widget *widget, int type,
                                     unsigned int x, unsigned int y,
                                     int delta_x, int delta_y);

struct g_canvas *g_canvas_create();
struct canvas_ctx *g_canvas_ctx(struct g_canvas *);
void *g_canvas_userdata(struct g_canvas *canvas);

void g_canvas_set_userdata(struct g_canvas *canvas, void *userdata);
void g_canvas_set_redraw_fn(struct g_canvas*, g_canvas_redraw_fn fn);
void g_canvas_set_on_mouse_fn(struct g_canvas*, g_canvas_on_mouse_fn fn);
