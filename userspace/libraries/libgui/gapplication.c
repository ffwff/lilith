#pragma once

#include <wm/wmc.h>
#include <canvas.h>
#include <sys/gfx.h>
#include <sys/ioctl.h>
#include "coords.h"
#include "gui.h"

#define INIT_WIDTH 256
#define INIT_HEIGHT 256

// application
struct g_application {
	int fb_fd;
	struct wmc_connection wmc_conn;
	struct fbdev_bitblit sprite;
    struct canvas_ctx *ctx;
    
    // callbacks
    g_redraw_cb redraw_cb;
    g_key_cb key_cb;
};

int g_application_init(struct g_application *app, int width, int height) {
	app->fb_fd = open("/fb0", 0);
	wmc_connection_init(&app->wmc_conn);
    app->sprite = (struct fbdev_bitblit){
        .target_buffer = GFX_BACK_BUFFER,
        .source = 0,
        .x = 0,
        .y = 0,
        .width  = INIT_WIDTH,
        .height = INIT_HEIGHT,
        .type = GFX_BITBLIT_SURFACE
    };
    app->ctx = canvas_ctx_create(app->sprite.width,
                                 app->sprite.height,
                                 LIBCANVAS_FORMAT_RGB24);

    app->redraw_cb = 0;
    app->key_cb = 0;
}

int g_application_redraw(struct g_application *app) {
    if (app->redraw_cb) {
        return app->redraw_cb(app);
    }
    return 0;
}

static int g_application_on_key(struct g_application *app, int ch) {
    if (app->key_cb) {
        return app->key_cb(app, ch);
    }
    return 0;
}

void g_application_run(struct g_application *app) {
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
                needs_redraw = g_application_on_key(app, atom.keyboard_event.ch);

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
}

// getters

struct canvas_ctx *g_application_ctx(struct g_application *app) {
    return app->ctx;
}

// callbacks

void g_application_set_redraw_cb(struct g_application *app, g_redraw_cb cb) {
    app->redraw_cb = cb;
}

void g_application_set_key_cb(struct g_application *app, g_key_cb cb) {
    app->key_cb = cb;
}
