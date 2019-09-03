#pragma once

struct mouse_packet {
    unsigned long x, y, attr_byte;
};

#define MOUSE_ATTR_LEFT_BTN   (1 << 0)
#define MOUSE_ATTR_RIGHT_BTN  (1 << 1)
#define MOUSE_ATTR_MIDDLE_BTN (1 << 2)