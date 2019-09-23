#pragma once

struct g_decoration;

struct g_decoration *g_decoration_create();
void g_decoration_set_text(struct g_decoration *dec, const char *str);

struct g_widget *g_decoration_widget(struct g_decoration *);
void g_decoration_set_widget(struct g_decoration *, struct g_widget *);
int g_decoration_height(struct g_decoration *);
