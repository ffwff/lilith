#pragma once

struct mouse_packet {
    int ch;
    int modifiers;
} __attribute__((packed));