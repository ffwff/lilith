#pragma once

#include <stdlib.h>
#include "./gapplication-impl.h"

static int is_coord_in_sprite(struct g_application_sprite *sprite, unsigned int x, unsigned int y) {
    return sprite->x <= x && x <= (sprite->x + sprite->width) && 
           sprite->y <= y && y <= (sprite->y + sprite->height);
}

static int is_coord_in_bottom_right_corner(struct g_application_sprite *sprite, unsigned int x, unsigned int y) {
    const int RESIZE_DIST = 10;
    int cx = sprite->x + sprite->width;
    int cy = sprite->y + sprite->height;

    return abs(cx - (int)x) <= RESIZE_DIST && abs(cy - (int)y) <= RESIZE_DIST;
}
