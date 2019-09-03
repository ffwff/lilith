#pragma once

#include <stdint.h>

struct fbdev_bitblit {
    int32_t target_buffer;
    uint32_t *source;
    uint32_t x, y, width, height;
    int32_t type;
};

// ioctl values
#define GFX_BITBLIT 3
#define GFX_SWAPBUF 4

// target_buffer arg
#define GFX_FRONT_BUFFER 0
#define GFX_BACK_BUFFER  1

// type arg
#define GFX_BITBLIT_SURFACE       0
#define GFX_BITBLIT_COLOR         1
#define GFX_BITBLIT_SURFACE_ALPHA 2