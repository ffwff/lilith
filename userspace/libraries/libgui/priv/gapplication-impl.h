#pragma once

struct g_application {
  int fb_fd;
  struct wmc_connection wmc_conn;
  struct fbdev_bitblit sprite;
  struct canvas_ctx *ctx;
    
  struct g_widget_array widgets;

  // callbacks
  g_redraw_cb redraw_cb;
  g_key_cb key_cb;
    
  void *userdata;
};
