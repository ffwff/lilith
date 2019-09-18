#pragma once

struct g_decoration;

struct g_decoration *g_decoration_create();
void g_decoration_set_text(struct g_decoration *dec, const char *str);
