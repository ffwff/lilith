#pragma once

#include <stdint.h>

struct wm_atom_redraw {
    int needs_redraw;
};

struct wm_atom_move {
    uint32_t x;
    uint32_t y;
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