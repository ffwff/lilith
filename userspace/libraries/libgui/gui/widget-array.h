#pragma once

#include <stdlib.h>

struct g_widget_array {
  struct g_widget **data;
  size_t len;
};

void g_widget_array_init(struct g_widget_array *array);
void g_widget_array_push(struct g_widget_array *array, struct g_widget *widget);
