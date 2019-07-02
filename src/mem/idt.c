#include "mem/idt.h"

// IDT
extern void kload_idt(uint32_t idt_ptr);

static void init_idt(int num, uint16_t select, uint32_t offset, uint16_t type) {
    kidt[num].offset_1 = (offset & 0xffff);
    kidt[num].offset_2 = (offset & 0xffff0000) >> 16;
    kidt[num].selector = select;
    kidt[num].type_attr = type;
    kidt[num].zero = 0;
}

static void irq_install(uint16_t num, uint32_t offset) {
    init_idt(0x20 + num, KERNEL_CODE_SEGMENT_OFFSET, offset, INTERRUPT_GATE);
}

void kinit_idt() {
    kidtr.limit = sizeof(struct idt_entry) * IDT_SIZE - 1;
    kidtr.base = (uint32_t)&kidt;
    kload_idt((uint32_t)&kidtr);
}
