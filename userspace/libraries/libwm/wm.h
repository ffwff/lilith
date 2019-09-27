#pragma once

#include <syscalls.h>

/* Connection request */
struct wm_connection_request {
    pid_t pid;
    unsigned int event_mask;
    unsigned int properties;
};

#define WM_PROPERTY_NO_FOCUS   (1 << 0)
#define WM_PROPERTY_ROOT       (1 << 1)

/* Atoms */

// Create
struct wm_atom_win_create {
    unsigned int width, height;
};

// Move

struct wm_atom_move {
    unsigned int x;
    unsigned int y;
};

// Redraw

struct wm_atom_redraw {
    int force_redraw;
};

// Response

struct wm_atom_respond {
    int retval;
};

// Refresh

struct wm_atom_win_refresh {
    int did_redraw;
};

// Mouse event
enum wm_atom_mouse_event_type {
    WM_MOUSE_RELEASE = 0,
    WM_MOUSE_PRESS = 1,
};

struct wm_atom_mouse_event {
    enum wm_atom_mouse_event_type type;
    unsigned int x, y;
    int delta_x, delta_y;
};

// Keyboard event

struct wm_atom_keyboard_event {
    int ch;
    int modifiers;
};

// Query

struct wm_atom_screen_query {
    unsigned int width, height;
};

struct wm_atom {
    int type;
    union {
        struct wm_atom_redraw redraw;
        struct wm_atom_move move;
        struct wm_atom_respond respond;
        struct wm_atom_mouse_event mouse_event;
        struct wm_atom_keyboard_event keyboard_event;
        struct wm_atom_win_refresh win_refresh;
        struct wm_atom_win_create win_create;
        struct wm_atom_screen_query screen_query;
    };
};

#define ATOM_REDRAW_TYPE           0
#define ATOM_RESPOND_TYPE          1
#define ATOM_MOVE_TYPE             2
#define ATOM_MOUSE_EVENT_TYPE      3
#define ATOM_KEYBOARD_EVENT_TYPE   4
#define ATOM_WIN_REFRESH_TYPE      5
#define ATOM_WIN_CREATE_TYPE       6
#define ATOM_SCREEN_QUERY_TYPE     7

#define ATOM_REDRAW_MASK            (1 << ATOM_REDRAW_TYPE)
#define ATOM_RESPOND_MASK           (1 << ATOM_RESPOND_TYPE)
#define ATOM_MOVE_MASK              (1 << ATOM_MOVE_TYPE)
#define ATOM_MOUSE_EVENT_MASK       (1 << ATOM_MOUSE_EVENT_TYPE)
#define ATOM_KEYBOARD_EVENT_MASK    (1 << ATOM_KEYBOARD_EVENT_TYPE)
#define ATOM_WIN_REFRESH_MASK       (1 << ATOM_WIN_REFRESH_TYPE)
#define ATOM_SCREEN_QUERY_TYPE_MASK (1 << ATOM_SCREEN_QUERY_TYPE)

static inline int wm_atom_eq(struct wm_atom *a, struct wm_atom *b) {
    if(a->type != b->type)
        return 0;
    switch(a->type) {
        case ATOM_REDRAW_TYPE: {
            return 1;
        }
        case ATOM_RESPOND_TYPE: {
            return a->respond.retval == b->respond.retval;
        }
        case ATOM_MOVE_TYPE: {
            return a->move.x == b->move.x &&
                   a->move.y == b->move.y;
        }
        case ATOM_MOUSE_EVENT_TYPE: {
            return a->mouse_event.type == b->mouse_event.type &&
                   a->mouse_event.x == b->mouse_event.x &&
                   a->mouse_event.y == b->mouse_event.y;
        }
    }
    return 0;
}
