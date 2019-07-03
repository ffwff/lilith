#pragma once

#include "stdint.h"

#define GDT_SIZE 3

struct gdtr {
    uint16_t size;
    uint32_t offset;
} __attribute__((packed));

struct gdt_entry {
    uint16_t limit_low;
    uint16_t base_low;
    uint8_t base_middle;
    uint8_t access;
    uint8_t granularity;
    uint8_t base_high;
} __attribute__((packed));

struct gdtr kgdtr;
struct gdt_entry kgdt[GDT_SIZE];

void kinit_gdtr();