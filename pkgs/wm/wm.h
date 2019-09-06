#pragma once

// Configure

struct wm_atom_configure {
    unsigned long event_mask;
};

// Move

struct wm_atom_move {
    unsigned long x;
    unsigned long y;
};

// Redraw

struct wm_atom_redraw {
    int force_redraw;
};

// Response

struct wm_atom_respond {
    int retval;
};

// Mouse event
enum wm_atom_mouse_event_type {
    WM_MOUSE_RELEASE = 0,
    WM_MOUSE_PRESS = 1,
};

struct wm_atom_mouse_event {
    enum wm_atom_mouse_event_type type;
    unsigned long x, y;
};

struct wm_atom {
    int type;
    union {
        struct wm_atom_redraw redraw;
        struct wm_atom_move move;
        struct wm_atom_respond respond;
        struct wm_atom_mouse_event mouse_event;
        struct wm_atom_configure configure;
    };
};

#define ATOM_REDRAW_TYPE        0
#define ATOM_RESPOND_TYPE       1
#define ATOM_MOVE_TYPE          2
#define ATOM_MOUSE_EVENT_TYPE   3
#define ATOM_CONFIGURE_TYPE     4

#define ATOM_REDRAW_MASK        (1 << ATOM_REDRAW_TYPE)
#define ATOM_RESPOND_MASK       (1 << ATOM_RESPOND_TYPE)
#define ATOM_MOVE_MASK          (1 << ATOM_MOVE_TYPE)
#define ATOM_MOUSE_EVENT_MASK   (1 << ATOM_MOUSE_EVENT_TYPE)
#define ATOM_CONFIGURE_MASK     (1 << ATOM_CONFIGURE_TYPE)

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