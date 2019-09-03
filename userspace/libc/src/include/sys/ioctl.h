#pragma once

#include <stdint.h>

struct winsize {
    uint16_t ws_row;    /* rows, in characters */
    uint16_t ws_col;    /* columns, in characters */
    uint16_t ws_xpixel; /* horizontal size, pixels */
    uint16_t ws_ypixel; /* vertical size, pixels */
};

int ioctl(int fd, int request, void *arg);

// TCSA*            0, 1
#define TIOCGWINSZ  2
#define TIOCGSTATE  5
