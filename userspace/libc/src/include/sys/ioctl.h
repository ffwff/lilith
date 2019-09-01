#pragma once

struct winsize {
    unsigned short ws_row;    /* rows, in characters */
    unsigned short ws_col;    /* columns, in characters */
    unsigned short ws_xpixel; /* horizontal size, pixels */
    unsigned short ws_ypixel; /* vertical size, pixels */
};

struct fbdev_bitblit {
    int target_buffer;
    unsigned long *source;
    unsigned long x, y, width, height;
};

int ioctl(int fd, int request, void *arg);

// TCSA*            0, 1
#define TIOCGWINSZ  2
#define GFX_BITBLIT 3
#define GFX_SWAPBUF 4

#define GFX_FRONT_BUFFER 0
#define GFX_BACK_BUFFER 1