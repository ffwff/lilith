#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/gfx.h>
#include <sys/ioctl.h>
#include <sys/mouse.h>
#include <sys/kbd.h>
#include <syscalls.h>

#include <wm/wm.h>

#define STB_IMAGE_IMPLEMENTATION
#define STBI_ASSERT(x)
#include <stb/stb_image.h>

const int channels = 4;
#define CURSOR_FILE "/hd0/share/cursors/cursor.png"
#define WALLPAPER_FILE "/hd0/share/papes/yuki.jpg"

static void filter_data(struct fbdev_bitblit *sprite) {
    unsigned char *data = (unsigned char *)sprite->source;
    for (unsigned long i = 0; i < (sprite->width * sprite->height * 4); i += 4) {
        unsigned char r = data[i + 0];
        unsigned char g = data[i + 1];
        unsigned char b = data[i + 2];
        data[i + 0] = b;
        data[i + 1] = g;
        data[i + 2] = r;
        data[i + 3] = 0;
    }
}

static void filter_data_with_alpha(struct fbdev_bitblit *sprite) {
    unsigned char *data = (unsigned char *)sprite->source;
    for (unsigned long i = 0; i < (sprite->width * sprite->height * 4); i += 4) {
        unsigned char r = data[i + 0];
        unsigned char g = data[i + 1];
        unsigned char b = data[i + 2];
        unsigned char a = data[i + 3];
        // premultiply by alpha / 0xff
        data[i + 0] = (b * a) >> 8;
        data[i + 1] = (g * a) >> 8;
        data[i + 2] = (r * a) >> 8;
    }
}

static void panic(const char *s) {
    puts(s);
    exit(1);
}

#define min(x, y) ((x)<(y)?(x):(y))

#define PACKET_TIMEOUT 100000
#define FRAME_WAIT 10000

/* WM State */

struct wm_state;
struct wm_window;
struct wm_window_prog;
struct wm_window_sprite;

#define WM_EVENT_QUEUE_LEN 128

struct wm_state {
    int needs_redraw;
    int mouse_fd;
    struct wm_window *mouse_win; // weakref
    int kbd_fd;
    struct wm_atom last_mouse_atom;
    struct wm_window *windows;
    int nwindows;
    struct wm_atom queue[WM_EVENT_QUEUE_LEN];
    int queue_len;
    int focused_wid;
};

#define WM_WINDOW_PROG   0
#define WM_WINDOW_SPRITE 1

struct wm_window_prog {
    int mfd, sfd;
    unsigned int event_mask;
    unsigned int x, y, width, height;
};

struct wm_window_sprite {
    struct fbdev_bitblit sprite;
};

struct wm_window {
    int type;
    int wid;
    union {
        struct wm_window_prog prog;
        struct wm_window_sprite sprite;
    } as;
    size_t z_index;
};

/* IPC */

int win_write_and_wait(struct wm_window_prog *prog,
                       struct wm_atom *write_atom,
                       struct wm_atom *respond_atom) {
    ftruncate(prog->mfd, 0);
    write(prog->mfd, (char *)write_atom, sizeof(struct wm_atom));
    if (waitfd(prog->sfd, PACKET_TIMEOUT) < 0) {
        ftruncate(prog->sfd, 0);
        return 0;
    }
    // respond received
    return read(prog->sfd, (char *)respond_atom, sizeof(struct wm_atom));
}

/* WINDOW */

struct wm_window *wm_add_window(struct wm_state *state) {
    state->windows = realloc(state->windows, state->nwindows + 1);
    struct wm_window *win = &state->windows[state->nwindows++];
    memset(win, 0, sizeof(struct wm_window));
    win->wid = state->nwindows;
    return win;
}

struct wm_window *wm_add_win_prog(struct wm_state *state, int mfd, int sfd) {
    struct wm_window *win = wm_add_window(state);
    win->z_index = 1;
    win->type = WM_WINDOW_PROG;
    win->as.prog.mfd = mfd;
    win->as.prog.sfd = sfd;
    state->focused_wid = win->wid;
    return win;
}

struct wm_window *wm_add_sprite(struct wm_state *state, struct wm_window_sprite *sprite) {
    struct wm_window *win = wm_add_window(state);
    win->z_index = 1;
    win->type = WM_WINDOW_SPRITE;
    win->as.sprite = *sprite;
    return win;
}

/* IMPL */

int wm_sort_windows_by_z_compar(const void *av, const void *bv) {
    const struct wm_window *a = av, *b = bv;
    if (a->z_index < b->z_index) return -1;
    else if(a->z_index == b->z_index) return 0;
    return 1;
}

void wm_sort_windows_by_z(struct wm_state *state) {
    int mouse_wid = state->mouse_win->wid;

    qsort(state->windows, state->nwindows, sizeof(struct wm_window), wm_sort_windows_by_z_compar);

    for (int i = 0; i < state->nwindows; i++) {
        struct wm_window *win = &state->windows[i];
        if (win->wid == mouse_wid) {
            state->mouse_win = win;
            break;
        }
    }
}

/* QUEUE */

void wm_add_queue(struct wm_state *state, struct wm_atom *atom) {
    if(state->queue_len == WM_EVENT_QUEUE_LEN) {
        return;
    }
    state->queue[state->queue_len++] = *atom;
}

/* CONNECTIONS */

int wm_handle_connection_request(struct wm_state *state, struct wm_connection_request *conn_req) {
    char path[128] = { 0 };

    snprintf(path, sizeof(path), "/pipes/wm:%d:m", conn_req->pid);
    int mfd = create(path);
    if(mfd < 0) { return 0; }

    snprintf(path, sizeof(path), "/pipes/wm:%d:s", conn_req->pid);
    int sfd = create(path);
    if(sfd < 0) { close(mfd); return 0; }

    struct wm_window *win = wm_add_win_prog(state, mfd, sfd);
    win->as.prog.event_mask = conn_req->event_mask;

    wm_sort_windows_by_z(state);
    return 1;
}

/* MISC */

int point_in_win_prog(struct wm_window_prog *prog, unsigned int x, unsigned int y) {
    return prog->x <= x && x <= (prog->x + prog->width) &&
           prog->y <= y && y <= (prog->y + prog->height);
}

int main(int argc, char **argv) {
    int fb_fd = open("/fb0", 0);

    // setup
    struct winsize ws;
    ioctl(fb_fd, TIOCGWINSZ, &ws);

    struct wm_state wm = {0};
    wm.focused_wid = -1;

    // wallpaper
    {
        struct wm_window_sprite pape_spr = {
            .sprite = (struct fbdev_bitblit){
                .target_buffer = GFX_BACK_BUFFER,
                .source = (unsigned long*)0x000066cc,
                .x = 0,
                .y = 0,
                .width = ws.ws_col,
                .height = ws.ws_row,
                .type = GFX_BITBLIT_COLOR
            }
        };
        struct wm_window *win = wm_add_sprite(&wm, &pape_spr);
        win->z_index = 0;
    }

    // mouse
    {
        wm.mouse_fd = open("/mouse/raw", 0);

        struct wm_window_sprite mouse_spr = {
            .sprite = (struct fbdev_bitblit){
                .target_buffer = GFX_BACK_BUFFER,
                .source = NULL,
                .x = 100,
                .y = 100,
                .width = 0,
                .height = 0,
                .type = GFX_BITBLIT_SURFACE_ALPHA
            }
        };
        printf("loading cursor...\n");
        int w, h, n;
        mouse_spr.sprite.source = (unsigned long *)stbi_load(CURSOR_FILE, &w, &h, &n, channels);
        if (!mouse_spr.sprite.source) panic("can't load mouse_spr");
        mouse_spr.sprite.width = w;
        mouse_spr.sprite.height = h;
        filter_data_with_alpha(&mouse_spr.sprite);

        wm.mouse_win = wm_add_sprite(&wm, &mouse_spr);
        wm.mouse_win->z_index = (size_t)-1;
    }

    // keyboard
    {
        wm.kbd_fd = open("/kbd/raw", 0);
    }

    wm_sort_windows_by_z(&wm);

    // sample win
    char *spawn_argv[] = {"cterm", NULL};
    spawnv("cterm", (char **)spawn_argv);

    // disable console
    ioctl(STDOUT_FILENO, TIOCGSTATE, 0);

    // control pipe
    int control_fd = create("/pipes/wm");

    wm.needs_redraw = 1;

    while(1) {
        {
            // control pipe
            struct wm_connection_request conn_req = { 0 };
            while(
                read(control_fd, (char *)&conn_req, sizeof(struct wm_connection_request))
                    == sizeof(struct wm_connection_request)
            ) {
                if (wm_handle_connection_request(&wm, &conn_req)) {
                    wm.needs_redraw = 1;
                }
            }
        }
        {
            // mouse
            struct mouse_packet mouse_packet;
            read(wm.mouse_fd, (char *)&mouse_packet, sizeof(mouse_packet));

            unsigned int speed = __builtin_ffs(mouse_packet.x + mouse_packet.y);
            struct fbdev_bitblit *sprite = &wm.mouse_win->as.sprite.sprite;

            struct wm_atom mouse_atom = { 0 };
            mouse_atom.type = ATOM_MOUSE_EVENT_TYPE;

            if (mouse_packet.x != 0) {
                // left = negative
                int delta_x = mouse_packet.x * speed;
                mouse_atom.mouse_event.delta_x = delta_x;

                if(!(delta_x < 0 && sprite->x < -delta_x)) {
                    sprite->x += delta_x;
                    sprite->x = min(sprite->x, ws.ws_col);
                }
                wm.needs_redraw = 1;
            }
            mouse_atom.mouse_event.x = sprite->x;

            if (mouse_packet.y != 0) {
                // bottom = negative
                int delta_y = -mouse_packet.y * speed;
                mouse_atom.mouse_event.delta_y = delta_y;

                if(!(delta_y < 0 && sprite->y < -delta_y)) {
                    sprite->y += delta_y;
                    sprite->y = min(sprite->y, ws.ws_row);
                }
                wm.needs_redraw = 1;
            }
            mouse_atom.mouse_event.y = sprite->y;

            if ((mouse_packet.attr_byte & MOUSE_ATTR_LEFT_BTN) != 0) {
                mouse_atom.mouse_event.type = WM_MOUSE_PRESS;
            } else {
                mouse_atom.mouse_event.type = WM_MOUSE_RELEASE;
            }

            if(!wm_atom_eq(&mouse_atom, &wm.last_mouse_atom)) {
                // focus on window
                if(mouse_atom.mouse_event.type == WM_MOUSE_PRESS) {
                    int old_wid = wm.focused_wid;
                    struct wm_window *focused_win = NULL;
                    for(int i = wm.nwindows; i >= 0; i--) {
                        if (wm.windows[i].type == WM_WINDOW_PROG &&
                            point_in_win_prog(&wm.windows[i].as.prog, sprite->x, sprite->y)) {
                            wm.focused_wid = wm.windows[i].wid;
                            focused_win = &wm.windows[i];
                            break;
                        }
                    }
                    if(old_wid != wm.focused_wid && focused_win) {
                        // TODO: not hard code this
                        focused_win->z_index = 2;
                        wm_sort_windows_by_z(&wm);
                    }
                }
                wm_add_queue(&wm, &mouse_atom);
            }

            wm.last_mouse_atom = mouse_atom;
        }
        {
            // keyboard
            struct keyboard_packet keyboard_packet = { 0 };
            read(wm.kbd_fd, (char *)&keyboard_packet, sizeof(keyboard_packet));
            if(keyboard_packet.ch) {
                struct wm_atom keyboard_atom = { 0 };
                keyboard_atom.type = ATOM_KEYBOARD_EVENT_TYPE;
                keyboard_atom.keyboard_event.ch = keyboard_packet.ch;
                keyboard_atom.keyboard_event.modifiers = keyboard_packet.modifiers;
                wm_add_queue(&wm, &keyboard_atom);
            }
        }
        for (int i = 0; i < wm.nwindows; i++) {
            struct wm_window *win = &wm.windows[i];
            switch (win->type) {
                case WM_WINDOW_PROG: {
                    int retval;
                    struct wm_atom respond_atom;

                    // transmit events in queue
                    if(wm.focused_wid == win->wid) {
                        for(int i = 0; i < wm.queue_len; i++) {
                            if((win->as.prog.event_mask & (1 << wm.queue[i].type)) != 0) {
                                win_write_and_wait(&win->as.prog, &wm.queue[i], &respond_atom);
                            }
                        }
                    }

                    // request a redraw
                    struct wm_atom redraw_atom = {
                        .type = ATOM_REDRAW_TYPE,
                        .redraw.force_redraw = wm.needs_redraw,
                    };
                    retval = win_write_and_wait(&win->as.prog, &redraw_atom, &respond_atom);

                    if (retval == sizeof(struct wm_atom)) {
                        if (respond_atom.type == ATOM_WIN_REFRESH_TYPE) {
                            win->as.prog.x = respond_atom.win_refresh.x;
                            win->as.prog.y = respond_atom.win_refresh.y;
                            win->as.prog.width = respond_atom.win_refresh.width;
                            win->as.prog.height = respond_atom.win_refresh.height;
                            if(respond_atom.win_refresh.did_redraw)
                                wm.needs_redraw = 1;
                        } else {
                            // TODO: wrong response atom
                        }
                    }
                    break;
                }
                case WM_WINDOW_SPRITE: {
                    ioctl(fb_fd, GFX_BITBLIT, &win->as.sprite.sprite);
                    break;
                }
            }
        }
        if (wm.needs_redraw) {
            ioctl(fb_fd, GFX_SWAPBUF, 0);
            wm.needs_redraw = 0;
        }
        wm.queue_len = 0;
        usleep(FRAME_WAIT);
    }

    return 0;
}