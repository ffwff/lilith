#include "gdt.h"

extern void kload_gdt(uint32_t);
extern void kload_tss();

static void init_gdt(int num, uint32_t base, uint32_t limit, uint32_t access, uint32_t gran) {
    kgdt[num].base_low = (base & 0xFFFF);
    kgdt[num].base_middle = (base >> 16) & 0xFF;
    kgdt[num].base_high = (base >> 24) & 0xFF;

    kgdt[num].limit_low = (limit & 0xFFFF);
    kgdt[num].granularity = (limit >> 16) & 0x0F;

    kgdt[num].granularity |= gran & 0xF0;
    kgdt[num].access = access;
}

static void write_tss(int32_t num, uint16_t ss0, uint32_t esp0) {
    uint32_t base = (uint32_t)&ktss;
    uint32_t limit = base + sizeof(ktss);
    init_gdt(num, base, limit, 0xE9, 0x00);

    ktss.ss0 = ss0;
    ktss.esp0 = esp0;
    ktss.cs = 0x0b;
    ktss.ss = ktss.ds = ktss.es = ktss.fs = ktss.gs = 0x13;
}

void kinit_gdtr() {
    kgdtr.size = sizeof(struct gdt_entry) * GDT_SIZE - 1;
    kgdtr.offset = (uint32_t)&kgdt;

    // kernel space
    init_gdt(0, 0x0, 0x0, 0x0, 0x0);          // null
    init_gdt(1, 0x0, 0xFFFFFFFF, 0x9A, 0xCF); // kernel code
    init_gdt(2, 0x0, 0xFFFFFFFF, 0x92, 0xCF); // kernel data
    init_gdt(3, 0x0, 0xFFFFFFFF, 0xFA, 0xCF); // user data
    init_gdt(4, 0x0, 0xFFFFFFFF, 0xF2, 0xCF); // user data
    write_tss(5, 0x10, 0x0);

    kload_gdt((uint32_t)&kgdtr);
    kload_tss();
}

void kset_stack(uint32_t stack) {
    ktss.esp0 = stack;
}