#pragma once

struct g_widget;

struct canvas_ctx *g_widget_ctx(struct g_widget *widget);
unsigned int g_widget_x(struct g_widget *widget);
unsigned int g_widget_y(struct g_widget *widget);
unsigned int g_widget_width(struct g_widget *widget);
unsigned int g_widget_height(struct g_widget *widget);
unsigned int g_widget_z_index(struct g_widget *widget);

void g_widget_set_x(struct g_widget *widget, unsigned int);
void g_widget_set_y(struct g_widget *widget, unsigned int);
void g_widget_set_width(struct g_widget *widget, unsigned int);
void g_widget_set_height(struct g_widget *widget, unsigned int);
void g_widget_set_z_index(struct g_widget *widget, unsigned int);
void g_widget_move_resize(struct g_widget *widget, unsigned int x,
            unsigned int y, unsigned int width, unsigned int height);
