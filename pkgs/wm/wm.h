#pragma once

struct wm_atom_move {
    unsigned long x;
    unsigned long y;
};

struct wm_atom_redraw {
    int needs_redraw;
};

struct wm_atom {
    int type;
    union {
        struct wm_atom_redraw redraw;
        struct wm_atom_move move;
    };
};

#define ATOM_REDRAW_TYPE    0
#define ATOM_RESPOND_TYPE   1
#define ATOM_MOVE_TYPE      2