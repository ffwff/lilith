#pragma once

#include "stdint.h"

#define GDT_SIZE 3

struct gdtr {
    uint16_t size;
    uint32_t offset;
} __attribute__((packed));

struct gdt_entry {
    uint16_t lim0_15;
    uint16_t base0_15;
    uint8_t base16_23;
    uint8_t acces;
    uint8_t lim16_19 : 4;
    uint8_t other : 4;
    uint8_t base24_31;
} __attribute__((packed));

struct gdtr kgdtr;
struct gdt_entry kgdt[GDT_SIZE];

void kinit_gdtr();