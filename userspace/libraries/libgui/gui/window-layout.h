#pragma once

struct g_window_layout;

struct g_window_layout *g_window_layout_create(struct g_application *app, struct g_widget *main_widget);
struct g_decoration *g_window_layout_decoration(struct g_window_layout *widget);
struct g_widget *g_window_layout_main_widget(struct g_window_layout *widget);
void g_window_layout_set_main_widget(struct g_window_layout *widget, struct g_widget *main_widget);
