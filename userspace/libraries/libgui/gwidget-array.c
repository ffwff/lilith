#include "gui.h"
#include "priv/gwidget-impl.h"

void g_widget_array_init(struct g_widget_array *array) {
  array->data = 0;
  array->len = 0;
}

void g_widget_array_push(struct g_widget_array *array, struct g_widget *widget) {
  size_t idx = array->len++;
  array->data = realloc(array->data, sizeof(struct g_widget *) * array->len);
  array->data[idx] = widget;
  qsort(array->data, array->len, sizeof(struct g_widget *), g_widget_cmp_z_index);
}
