#pragma once

struct g_canvas;

struct g_canvas *g_canvas_create();
struct canvas_ctx *g_canvas_ctx(struct g_canvas *);
typedef void (*g_canvas_redraw_fn)(struct g_widget *widget,
                                  struct g_application *app);
void g_canvas_set_redraw_fn(struct g_canvas*, g_canvas_redraw_fn fn);
