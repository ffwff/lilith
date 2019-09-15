#pragma once

struct g_application;
typedef int (*g_redraw_cb)(struct g_application *app);
typedef int (*g_key_cb)(struct g_application *app, int ch);
// typedef int (*g_mouse_cb)(struct g_application *app, int ch);

int g_application_init(struct g_application *app, int width, int height);
int g_application_redraw(struct g_application *app);
void g_application_run(struct g_application *app);

struct canvas_ctx *g_application_ctx(struct g_application *app);

void g_application_set_redraw_cb(struct g_application *app, g_redraw_cb cb);
void g_application_set_key_cb(struct g_application *app, g_key_cb cb);
