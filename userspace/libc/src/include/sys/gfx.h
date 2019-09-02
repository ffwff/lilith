#pragma once

struct fbdev_bitblit {
    int target_buffer;
    unsigned long *source;
    unsigned long x, y, width, height;
    int type;
};

// ioctl values
#define GFX_BITBLIT 3
#define GFX_SWAPBUF 4

// target_buffer arg
#define GFX_FRONT_BUFFER 0
#define GFX_BACK_BUFFER  1

// type arg
#define GFX_BITBLIT_SURFACE 0
#define GFX_BITBLIT_COLOR   1