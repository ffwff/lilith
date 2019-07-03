#include "mem/idt.h"
#include "mem/mem.h"

// IDT
extern void kload_idt(uint32_t idt_ptr);
extern void kirq_stub();

void kinit_idt(uint32_t num, uint16_t select, uint32_t offset, uint16_t type) {
    kidt[num].offset_1 = (offset & 0xffff);
    kidt[num].offset_2 = (offset & 0xffff0000) >> 16;
    kidt[num].selector = select;
    kidt[num].zero = 0;
    kidt[num].type_attr = type;
}

void kinit_idtr() {
    kidtr.limit = sizeof(struct idt_entry) * IDT_SIZE - 1;
    kidtr.base = (uint32_t)&kidt;
    // irqs
    for(int i = 0; i < 31; i++) {
        kinit_idt(i, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub, INTERRUPT_GATE);
    }
    kload_idt((uint32_t)&kidtr);
}
