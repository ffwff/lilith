#include "gdt.h"

extern void kload_gdt(uint32_t);

static void init_gdt(int num, uint32_t base, uint32_t limite, uint32_t acces, uint32_t other) {
    // NOTE:
    // base: where section begins
    // limite: where section ends
    // both in 1 byte unit
    kgdt[num].lim0_15 = (limite & 0xffff);
    kgdt[num].base0_15 = (base & 0xffff);
    kgdt[num].base16_23 = (base & 0xff0000) >> 16;
    kgdt[num].acces = acces;
    kgdt[num].lim16_19 = (limite & 0xf0000) >> 16;
    kgdt[num].other = (other & 0xf);
    kgdt[num].base24_31 = (base & 0xff000000) >> 24;
}

void kinit_gdtr() {
    kgdtr.size = sizeof(struct gdt_entry) * GDT_SIZE - 1;
    kgdtr.offset = (uint32_t)&kgdt;

    // kernel space
    init_gdt(0, 0x0, 0x0, 0x0, 0xCF);      /* null */
    init_gdt(1, 0x0, 0xFFFFF, 0x9A, 0xCF); /* code */
    init_gdt(2, 0x0, 0xFFFFF, 0x92, 0xCF); /* data */

    kload_gdt((uint32_t)&kgdtr);
}