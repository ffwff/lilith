#include "arch/idt.h"
#include "arch/mem.h"

// IDT
extern void kload_idt(uint32_t idt_ptr);

void kinit_idt(uint32_t num, uint16_t select, uint32_t offset, uint16_t type) {
    kidt[num].offset_1 = (offset & 0xffff);
    kidt[num].offset_2 = (offset & 0xffff0000) >> 16;
    kidt[num].selector = select;
    kidt[num].zero = 0;
    kidt[num].type_attr = type;
}

#pragma region bunch of kirq_stub
extern void kirq0();
extern void kirq1();
extern void kirq2();
extern void kirq3();
extern void kirq4();
extern void kirq5();
extern void kirq6();
extern void kirq7();
extern void kirq8();
extern void kirq9();
extern void kirq10();
extern void kirq11();
extern void kirq12();
extern void kirq13();
extern void kirq14();
extern void kirq15();
#pragma endregion

void kinit_idtr() {
    kidtr.limit = sizeof(struct idt_entry) * IDT_SIZE - 1;
    kidtr.base = (uint32_t)&kidt;
    // irqs
    #pragma region kirq_stub inits
    kinit_idt(32, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq0, INTERRUPT_GATE);
    kinit_idt(33, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq1, INTERRUPT_GATE);
    kinit_idt(34, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq2, INTERRUPT_GATE);
    kinit_idt(35, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq3, INTERRUPT_GATE);
    kinit_idt(36, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq4, INTERRUPT_GATE);
    kinit_idt(37, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq5, INTERRUPT_GATE);
    kinit_idt(38, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq6, INTERRUPT_GATE);
    kinit_idt(39, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq7, INTERRUPT_GATE);
    kinit_idt(40, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq8, INTERRUPT_GATE);
    kinit_idt(41, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq9, INTERRUPT_GATE);
    kinit_idt(42, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq10, INTERRUPT_GATE);
    kinit_idt(43, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq11, INTERRUPT_GATE);
    kinit_idt(44, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq12, INTERRUPT_GATE);
    kinit_idt(45, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq13, INTERRUPT_GATE);
    kinit_idt(46, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq14, INTERRUPT_GATE);
    kinit_idt(47, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq15, INTERRUPT_GATE);
    #pragma endregion
    kload_idt((uint32_t)&kidtr);
}
