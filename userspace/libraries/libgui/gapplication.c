#include <wm/wmc.h>
#include <canvas.h>
#include <sys/gfx.h>
#include <sys/ioctl.h>
#include "gui.h"
#include "priv/coords.h"
#include "priv/gapplication-impl.h"
#include "priv/gwidget-impl.h"

// application
struct g_application *g_application_create(int width, int height) {
  struct g_application *app = malloc(sizeof(struct g_application));
  if(!app) {
    return 0;
  }
  app->fb_fd = open("/fb0", O_RDWR);
  if(app->fb_fd < 0) {
    free(app);
    return 0;
  }
	if(!wmc_connection_init(&app->wmc_conn)) {
    close(app->fb_fd);
    free(app);
    return 0;
  }
  app->sprite = (struct fbdev_bitblit){
    .target_buffer = GFX_BACK_BUFFER,
    .source = 0,
    .x = 0,
    .y = 0,
    .width  = width,
    .height = height,
    .type = GFX_BITBLIT_SURFACE
  };
  app->ctx = canvas_ctx_create(app->sprite.width,
                 app->sprite.height,
                 LIBCANVAS_FORMAT_RGB24);
  g_widget_array_init(&app->widgets);

  if(!app->ctx) {
    close(app->fb_fd);
    wmc_connection_deinit(&app->wmc_conn);
    free(app);
    return 0;
  }
  app->redraw_cb = 0;
  app->key_cb = 0;
  app->userdata = 0;
  return app;
}

void g_application_destroy(struct g_application *app) {
  close(app->fb_fd);
  wmc_connection_deinit(&app->wmc_conn);
  free(app);
}

int g_application_redraw(struct g_application *app) {
  app->sprite.source = (unsigned long *)canvas_ctx_get_surface(app->ctx);
  int needs_redraw = 0;
  if (app->redraw_cb) {
    if (app->redraw_cb(app))
      needs_redraw = 1;
  }
  for(size_t i = 0; i < app->widgets.len; i++) {
    struct g_widget *widget = app->widgets.data[i];
    if(widget->redraw_fn(widget, app)) {
      canvas_ctx_bitblit(app->ctx, widget->ctx, widget->x, widget->y);
      needs_redraw = 1;
    }
  }
  return needs_redraw;
}

static int g_application_on_key(struct g_application *app, int ch) {
  if (app->key_cb) {
    app->key_cb(app, ch);
  }
  for(size_t i = 0; i < app->widgets.len; i++) {
    struct g_widget *widget = app->widgets.data[i];
    if(widget->on_key_fn) {
      widget->on_key_fn(widget, ch);
    }
  }
  return 1;
}

int g_application_run(struct g_application *app) {
  wmc_connection_obtain(&app->wmc_conn, ATOM_MOUSE_EVENT_MASK | ATOM_KEYBOARD_EVENT_MASK);

  // event loop
  int mouse_drag = 0;
  int mouse_resize = 0;

  struct wm_atom atom;
  int needs_redraw = 0;
  int retval = 0;
  while ((retval = wmc_recv_atom(&app->wmc_conn, &atom)) >= 0) {
    if(retval == 0)
      goto wait;
    switch (atom.type) {
      case ATOM_REDRAW_TYPE: {
        struct wm_atom respond_atom = {
          .type = ATOM_WIN_REFRESH_TYPE,
          .win_refresh = (struct wm_atom_win_refresh){
            .did_redraw = 0,
            .x = app->sprite.x,
            .y = app->sprite.y,
            .width = app->sprite.width,
            .height = app->sprite.height,
          }
        };
        needs_redraw = g_application_redraw(app);
        if (needs_redraw || atom.redraw.force_redraw) {
          needs_redraw = 0;
          respond_atom.win_refresh.did_redraw = 1;
          ioctl(app->fb_fd, GFX_BITBLIT, &app->sprite);
        }
        wmc_send_atom(&app->wmc_conn, &respond_atom);
        break;
      }
      case ATOM_MOVE_TYPE: {
        app->sprite.x = atom.move.x;
        app->sprite.y = atom.move.y;
        needs_redraw = 1;

        struct wm_atom respond_atom = {
          .type = ATOM_RESPOND_TYPE,
          .respond.retval = 0,
        };
        wmc_send_atom(&app->wmc_conn, &respond_atom);
        break;
      }
      case ATOM_MOUSE_EVENT_TYPE: {
        if(atom.mouse_event.type == WM_MOUSE_PRESS &&
           (is_coord_in_sprite(&app->sprite,
                     atom.mouse_event.x,
                     atom.mouse_event.y) ||
          mouse_drag)) {
          mouse_drag = 1;
          if(is_coord_in_bottom_right_corner(&app->sprite,
            atom.mouse_event.x,
            atom.mouse_event.y) || mouse_resize) {
            // resize
            mouse_resize = 1;
            app->sprite.width += atom.mouse_event.delta_x;
            app->sprite.height += atom.mouse_event.delta_y;
            canvas_ctx_resize_buffer(app->ctx, app->sprite.width, app->sprite.height);
            needs_redraw = g_application_redraw(app);
          } else {
            if(!(atom.mouse_event.delta_x < 0 && app->sprite.x < -atom.mouse_event.delta_x))
              app->sprite.x += atom.mouse_event.delta_x;
            if(!(atom.mouse_event.delta_y < 0 && app->sprite.y < -atom.mouse_event.delta_y))
              app->sprite.y += atom.mouse_event.delta_y;
          }
        } else if (atom.mouse_event.type == WM_MOUSE_RELEASE && mouse_drag) {
          mouse_drag = 0;
          mouse_resize = 0;
        }
        needs_redraw = 1;

        struct wm_atom respond_atom = {
          .type = ATOM_RESPOND_TYPE,
          .respond.retval = 0,
        };
        wmc_send_atom(&app->wmc_conn, &respond_atom);
        break;
      }
      case ATOM_KEYBOARD_EVENT_TYPE: {
        g_application_on_key(app, atom.keyboard_event.ch);

        struct wm_atom respond_atom = {
          .type = ATOM_RESPOND_TYPE,
          .respond.retval = 0,
        };
        wmc_send_atom(&app->wmc_conn, &respond_atom);
        break;
      }
    }
  wait:
    wmc_wait_atom(&app->wmc_conn);
  }
  
  return 0;
}

// getters

struct g_widget_array *g_application_widgets(struct g_application *app) {
  return &app->widgets;
}

struct canvas_ctx *g_application_ctx(struct g_application *app) {
  return app->ctx;
}

unsigned int g_application_x(struct g_application *app) {
  return app->sprite.x;
}

unsigned int g_application_y(struct g_application *app) {
  return app->sprite.y;
}

unsigned int g_application_width(struct g_application *app) {
  return app->sprite.width;
}

unsigned int g_application_height(struct g_application *app) {
  return app->sprite.height;
}

// properties

void *g_application_userdata(struct g_application *app) {
  return app->userdata;
}

void g_application_set_userdata(struct g_application *app, void *ptr) {
  app->userdata = ptr;
}

// callbacks

void g_application_set_redraw_cb(struct g_application *app, g_redraw_cb cb) {
  app->redraw_cb = cb;
}

void g_application_set_key_cb(struct g_application *app, g_key_cb cb) {
  app->key_cb = cb;
}
