#pragma once

struct keyboard_packet {
    int ch;
    int modifiers;
} __attribute__((packed));