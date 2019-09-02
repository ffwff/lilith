#pragma once

struct winsize {
    unsigned short ws_row;    /* rows, in characters */
    unsigned short ws_col;    /* columns, in characters */
    unsigned short ws_xpixel; /* horizontal size, pixels */
    unsigned short ws_ypixel; /* vertical size, pixels */
};

int ioctl(int fd, int request, void *arg);

// TCSA*            0, 1
#define TIOCGWINSZ  2
#define TIOCGSTATE  5
