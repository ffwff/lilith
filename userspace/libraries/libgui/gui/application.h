#pragma once

struct g_application;
typedef int (*g_redraw_cb)(struct g_application *app);
typedef int (*g_key_cb)(struct g_application *app, int ch);
typedef int (*g_mouse_cb)(struct g_application *app,
  unsigned int x,
  unsigned int y,
  unsigned int modifiers);

struct g_application *g_application_create(int width, int height);
void g_application_destroy(struct g_application *);
int g_application_redraw(struct g_application *app);
int g_application_run(struct g_application *app);

void g_application_add_widget(struct g_application *app, struct g_widget *widget);

struct canvas_ctx *g_application_ctx(struct g_application *app);
unsigned int g_application_x(struct g_application *app);
unsigned int g_application_y(struct g_application *app);
unsigned int g_application_width(struct g_application *app);
unsigned int g_application_height(struct g_application *app);

void *g_application_userdata(struct g_application *app);
void g_application_set_userdata(struct g_application *app, void *ptr);

void g_application_set_redraw_cb(struct g_application *app, g_redraw_cb cb);
void g_application_set_key_cb(struct g_application *app, g_key_cb cb);
