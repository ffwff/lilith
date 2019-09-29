#pragma once

struct g_widget;

struct canvas_ctx *g_widget_ctx(struct g_widget *widget);
int g_widget_x(struct g_widget *widget);
int g_widget_y(struct g_widget *widget);
int g_widget_width(struct g_widget *widget);
int g_widget_height(struct g_widget *widget);
int g_widget_z_index(struct g_widget *widget);

void g_widget_set_x(struct g_widget *widget, int);
void g_widget_set_y(struct g_widget *widget, int);
void g_widget_set_width(struct g_widget *widget, int);
void g_widget_set_height(struct g_widget *widget, int);
void g_widget_set_z_index(struct g_widget *widget, int);

void g_widget_move_resize(struct g_widget *widget, int x, int y, int width, int height);
void g_widget_move(struct g_widget *widget, int x, int y);
void g_widget_resize(struct g_widget *widget, int width, int height);

int g_widget_needs_redraw(struct g_widget *widget);
void g_widget_set_needs_redraw(struct g_widget *widget, int needs_redraw);

struct g_application *g_widget_application(struct g_widget *widget);

