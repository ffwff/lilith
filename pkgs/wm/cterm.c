#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/gfx.h>
#include <sys/ioctl.h>
#include <syscalls.h>

#define LIBCANVAS_IMPLEMENTATION
#include <canvas.h>

#include "../.build/font8x8_basic.h"
#include "wmc.h"

#define INIT_WIDTH 400
#define INIT_HEIGHT 256
#define FONT_WIDTH 8
#define FONT_HEIGHT 8

int clamp(int d, int min, int max) {
    if(d < min) return min;
    if(d < max) return max;
    return d;
}

void canvas_ctx_draw_character(struct canvas_ctx *ctx, int xs, int ys, const char ch) {
    char *bitmap = font8x8_basic[ch];
    if(canvas_ctx_get_format(ctx) != LIBCANVAS_FORMAT_RGB24)
        return;
    unsigned long *data = (unsigned long *)canvas_ctx_get_surface(ctx);
    for (int x = 0; x < FONT_WIDTH; x++) {
        for (int y = 0; y < FONT_HEIGHT; y++) {
            if (bitmap[y] & 1 << x) {
                data[(ys + y) * canvas_ctx_get_width(ctx) + (xs + x)] = 0xffffffff;
            }
        }
    }
}

void canvas_ctx_draw_text(struct canvas_ctx *ctx, int xs, int ys, const char *s) {
    int x = xs, y = ys;
    while(*s) {
        canvas_ctx_draw_character(ctx, x, y, *s);
        x += FONT_WIDTH;
        s++;
    }
}

/* CHECKS */

int is_coord_in_sprite(struct fbdev_bitblit *sprite, unsigned int x, unsigned int y) {
    return sprite->x <= x && x <= (sprite->x + sprite->width) && 
           sprite->y <= y && y <= (sprite->y + sprite->height);
}

int is_coord_in_bottom_right_corner(struct fbdev_bitblit *sprite, unsigned int x, unsigned int y) {
    const int RESIZE_DIST = 10;
    int cx = sprite->x + sprite->width;
    int cy = sprite->y + sprite->height;

    return abs(cx - (int)x) <= RESIZE_DIST && abs(cy - (int)y) <= RESIZE_DIST;
}

/* WINDOW DRAWING */

struct cterm_state {
    struct canvas_ctx *ctx;
    struct fbdev_bitblit sprite;
    int fb_fd;
    struct wmc_connection wmc_conn;
    int cwidth, cheight; // in number of characters
    int cx, cy;
    int root_width, root_height;
    int root_x, root_y;
    char *buffer;
    size_t buffer_len;
    int in_fd, out_fd;
};

void cterm_init(struct cterm_state *state) {
    state->sprite = (struct fbdev_bitblit){
        .target_buffer = GFX_BACK_BUFFER,
        .source = 0,
        .x = 0,
        .y = 0,
        .width  = INIT_WIDTH,
        .height = INIT_HEIGHT,
        .type = GFX_BITBLIT_SURFACE
    };
    state->ctx = canvas_ctx_create(state->sprite.width,
                                   state->sprite.height,
                                   LIBCANVAS_FORMAT_RGB24);
    state->fb_fd = open("/fb0", 0);
    wmc_connection_init(&state->wmc_conn);
    state->cwidth = 0;
    state->cheight = 0;
    state->cx = 0;
    state->cy = 0;
    state->buffer = 0;
    state->buffer_len = 0;

    char path[128] = { 0 };

    // snprintf(path, sizeof(path), "/pipes/cterm:%d:in", getpid());
    // state->in_fd = create(path);

    snprintf(path, sizeof(path), "/pipes/cterm:%d:out", getpid());
    state->out_fd = create(path);
}

void cterm_draw_buffer(struct cterm_state *state);
void cterm_draw(struct cterm_state *state) {
    state->sprite.source = (unsigned long *)canvas_ctx_get_surface(state->ctx);
    // window decorations
    canvas_ctx_fill_rect(state->ctx, 0, 0,
        state->sprite.width, state->sprite.height,
        canvas_color_rgb(0x32, 0x36, 0x39));
    canvas_ctx_stroke_rect(state->ctx, 0, 0,
        state->sprite.width - 1, state->sprite.height - 1,
        canvas_color_rgb(0x20, 0x21, 0x24));

    {
        const char *title = "Terminal";
        int x_title = (state->sprite.width - strlen(title) * FONT_WIDTH) / 2;
        canvas_ctx_draw_text(state->ctx, x_title, 10, title);
    }

    // calculate root widget
    state->root_x = 1;
    state->root_y = FONT_HEIGHT + 15;
    state->root_width = state->sprite.width - state->root_x - 1;
    state->root_height = state->sprite.height - state->root_y - 1;

    // calculate characters and buffer
    state->cwidth  = state->root_width / FONT_WIDTH;
    state->cheight = state->root_height / FONT_HEIGHT;
    size_t new_len = state->cwidth * state->cheight;
    if(new_len != state->buffer_len) {
        state->buffer = realloc(state->buffer, new_len);
        if(new_len > state->buffer_len) {
            memset(state->buffer + state->buffer_len, 0, new_len - state->buffer_len);
        }
        state->buffer_len = new_len;
    }
    cterm_draw_buffer(state);
}

void cterm_draw_buffer(struct cterm_state *state) {
    canvas_ctx_fill_rect(state->ctx, state->root_x, state->root_y,
        state->root_width, state->root_height,
        canvas_color_rgb(0, 0, 0));
    for(int y = 0; y < state->cheight; y++) {
        for(int x = 0; x < state->cwidth; x++) {
            canvas_ctx_draw_character(state->ctx,
                    state->root_x + x * FONT_WIDTH, state->root_y + y * FONT_HEIGHT,
                    state->buffer[y * state->cwidth + x]);
        }
    }
}

void cterm_newline(struct cterm_state *state) {
    state->cx = 0;
    if(state->cy == state->cheight - 1) {
        // scroll
        for(int y = 0; y < state->cheight - 1; y++) {
            for(int x = 0; x < state->cwidth; x++) {
                state->buffer[y * state->cwidth + x]
                    = state->buffer[(y + 1) * state->cwidth + x];
            }
        }
        cterm_draw_buffer(state);
    } else {
        state->cy++;
    }
}

void cterm_advance(struct cterm_state *state) {
    state->cx++;
    if(state->cx == state->cwidth) {
        cterm_newline(state);
    }
}

void cterm_add_character(struct cterm_state *state, char ch) {
    if(ch == '\n') {
        cterm_newline(state);
    } else {
        state->buffer[state->cy * state->cwidth + state->cx] = ch;
        canvas_ctx_draw_character(state->ctx,
                state->root_x + state->cx * FONT_WIDTH,
                state->root_y + state->cy * FONT_HEIGHT,
                ch);
        cterm_advance(state);
    }
}

int cterm_read_buf(struct cterm_state *state) {
    char buf[4096];
    int retval = read(state->out_fd, buf, sizeof(buf));
    if(retval <= 0) return retval;
    for(int i = 0; i < retval; i++) {
        cterm_add_character(state, buf[i]);
    }
    return retval;
}

int main(int argc, char **argv) {
    struct cterm_state state = { 0 };
    cterm_init(&state);
    cterm_draw(&state);

    // spawn main
    struct startup_info s_info = {
        .stdin = STDIN_FILENO,
        .stdout = state.out_fd,
        .stderr = state.out_fd,
    };
    char *spawn_argv[] = {"/hd0/main", NULL};
    spawnxv(&s_info, "/hd0/main", (char **)spawn_argv);

    wmc_connection_obtain(&state.wmc_conn, ATOM_MOUSE_EVENT_MASK | ATOM_KEYBOARD_EVENT_MASK);

    // event loop
    int mouse_drag = 0;
    int mouse_resize = 0;

    struct wm_atom atom;
    int needs_redraw = 0;
    int retval = 0;
    while ((retval = wmc_recv_atom(&state.wmc_conn, &atom)) >= 0) {
        if(retval == 0)
            goto wait;
        switch (atom.type) {
            case ATOM_REDRAW_TYPE: {
                struct wm_atom respond_atom = {
                    .type = ATOM_WIN_REFRESH_TYPE,
                    .win_refresh = (struct wm_atom_win_refresh){
                        .did_redraw = 0,
                        .x = state.sprite.x,
                        .y = state.sprite.y,
                        .width = state.sprite.width,
                        .height = state.sprite.height,
                    }
                };
                if (cterm_read_buf(&state) || needs_redraw || atom.redraw.force_redraw) {
                    needs_redraw = 0;
                    respond_atom.win_refresh.did_redraw = 1;
                    ioctl(state.fb_fd, GFX_BITBLIT, &state.sprite);
                }
                wmc_send_atom(&state.wmc_conn, &respond_atom);
                break;
            }
            case ATOM_MOVE_TYPE: {
                state.sprite.x = atom.move.x;
                state.sprite.y = atom.move.y;
                needs_redraw = 1;

                struct wm_atom respond_atom = {
                    .type = ATOM_RESPOND_TYPE,
                    .respond.retval = 0,
                };
                wmc_send_atom(&state.wmc_conn, &respond_atom);
                break;
            }
            case ATOM_MOUSE_EVENT_TYPE: {
                if(atom.mouse_event.type == WM_MOUSE_PRESS &&
                   (is_coord_in_sprite(&state.sprite,
                                       atom.mouse_event.x,
                                       atom.mouse_event.y) ||
                    mouse_drag)) {
                    mouse_drag = 1;
                    if(is_coord_in_bottom_right_corner(&state.sprite,
                        atom.mouse_event.x,
                        atom.mouse_event.y) || mouse_resize) {
                        // resize
                        mouse_resize = 1;
                        state.sprite.width += atom.mouse_event.delta_x;
                        state.sprite.height += atom.mouse_event.delta_y;
                        canvas_ctx_resize_buffer(state.ctx, state.sprite.width, state.sprite.height);
                        cterm_draw(&state);
                    } else {
                        if(!(atom.mouse_event.delta_x < 0 && state.sprite.x < -atom.mouse_event.delta_x))
                            state.sprite.x += atom.mouse_event.delta_x;
                        if(!(atom.mouse_event.delta_y < 0 && state.sprite.y < -atom.mouse_event.delta_y))
                            state.sprite.y += atom.mouse_event.delta_y;
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
                wmc_send_atom(&state.wmc_conn, &respond_atom);
                break;
            }
            case ATOM_KEYBOARD_EVENT_TYPE: {
                cterm_add_character(&state, atom.keyboard_event.ch);
                needs_redraw = 1;

                struct wm_atom respond_atom = {
                    .type = ATOM_RESPOND_TYPE,
                    .respond.retval = 0,
                };
                wmc_send_atom(&state.wmc_conn, &respond_atom);
                break;
            }
        }
    wait:
        wmc_wait_atom(&state.wmc_conn);
    }

    return 0;
}