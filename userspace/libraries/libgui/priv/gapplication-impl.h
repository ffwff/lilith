#pragma once

struct g_application_sprite {
  unsigned int x, y, width, height;
  unsigned int *source;
  int alpha;
};

struct g_application {
  int bitmapfd;
  void *bitmap;
  
  struct wmc_connection wmc_conn;
  unsigned int event_mask;
  unsigned int wm_properties;
  struct g_application_sprite sprite;
  struct canvas_ctx *ctx;
    
  struct g_widget_array widgets;
  struct g_widget *main_widget;

  // callbacks
  g_redraw_cb redraw_cb;
  g_key_cb key_cb;
  g_mouse_cb mouse_cb;
  g_close_cb close_cb;
  g_timeout_cb timeout_cb;
  useconds_t usec_timeout;

  void *userdata;
  int running;
};
