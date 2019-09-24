#pragma once

struct keyboard_packet {
    int ch;
    int modifiers;
} __attribute__((packed));

#define KBD_MOD_SHIFTL  (1 << 0)
#define KBD_MOD_SHIFTR  (1 << 1)
#define KBD_MOD_CTRLL   (1 << 3)
#define KBD_MOD_CTRLR   (1 << 4)
