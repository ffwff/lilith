#include "gdt.h"

extern void kload_gdt(uint32_t);

static void init_gdt(int num, uint32_t base, uint32_t limit, uint32_t access, uint32_t gran) {
    kgdt[num].base_low = (base & 0xFFFF);
    kgdt[num].base_middle = (base >> 16) & 0xFF;
    kgdt[num].base_high = (base >> 24) & 0xFF;

    kgdt[num].limit_low = (limit & 0xFFFF);
    kgdt[num].granularity = (limit >> 16) & 0x0F;

    kgdt[num].granularity |= gran & 0xF0;
    kgdt[num].access = access;
}

void kinit_gdtr() {
    kgdtr.size = sizeof(struct gdt_entry) * GDT_SIZE - 1;
    kgdtr.offset = (uint32_t)&kgdt;

    // kernel space
    init_gdt(0, 0x0, 0x0, 0x0, 0x0);      /* null */
    init_gdt(1, 0x0, 0xFFFFFFFF, 0x9A, 0xCF); /* code */
    init_gdt(2, 0x0, 0xFFFFFFFF, 0x92, 0xCF); /* data */

    kload_gdt((uint32_t)&kgdtr);
}