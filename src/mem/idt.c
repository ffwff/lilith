#include "mem/idt.h"
#include "mem/mem.h"

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
extern void kirq_stub0();
extern void kirq_stub1();
extern void kirq_stub2();
extern void kirq_stub3();
extern void kirq_stub4();
extern void kirq_stub5();
extern void kirq_stub6();
extern void kirq_stub7();
extern void kirq_stub8();
extern void kirq_stub9();
extern void kirq_stub10();
extern void kirq_stub11();
extern void kirq_stub12();
extern void kirq_stub13();
extern void kirq_stub14();
extern void kirq_stub15();
extern void kirq_stub16();
extern void kirq_stub17();
extern void kirq_stub18();
extern void kirq_stub19();
extern void kirq_stub20();
extern void kirq_stub21();
extern void kirq_stub22();
extern void kirq_stub23();
extern void kirq_stub24();
extern void kirq_stub25();
extern void kirq_stub26();
extern void kirq_stub27();
extern void kirq_stub28();
extern void kirq_stub29();
extern void kirq_stub30();
#pragma endregion

void kinit_idtr() {
    kidtr.limit = sizeof(struct idt_entry) * IDT_SIZE - 1;
    kidtr.base = (uint32_t)&kidt;
    memset(&kidt, 0, sizeof(struct idt_entry)*IDT_SIZE);
    // irqs
    #pragma region kirq_stub inits
    kinit_idt(0, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub0, INTERRUPT_GATE);
    kinit_idt(1, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub1, INTERRUPT_GATE);
    kinit_idt(2, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub2, INTERRUPT_GATE);
    kinit_idt(3, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub3, INTERRUPT_GATE);
    kinit_idt(4, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub4, INTERRUPT_GATE);
    kinit_idt(5, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub5, INTERRUPT_GATE);
    kinit_idt(6, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub6, INTERRUPT_GATE);
    kinit_idt(7, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub7, INTERRUPT_GATE);
    kinit_idt(8, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub8, INTERRUPT_GATE);
    kinit_idt(9, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub9, INTERRUPT_GATE);
    kinit_idt(10, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub10, INTERRUPT_GATE);
    kinit_idt(11, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub11, INTERRUPT_GATE);
    kinit_idt(12, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub12, INTERRUPT_GATE);
    kinit_idt(13, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub13, INTERRUPT_GATE);
    kinit_idt(14, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub14, INTERRUPT_GATE);
    kinit_idt(15, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub15, INTERRUPT_GATE);
    kinit_idt(16, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub16, INTERRUPT_GATE);
    kinit_idt(17, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub17, INTERRUPT_GATE);
    kinit_idt(18, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub18, INTERRUPT_GATE);
    kinit_idt(19, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub19, INTERRUPT_GATE);
    kinit_idt(20, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub20, INTERRUPT_GATE);
    kinit_idt(21, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub21, INTERRUPT_GATE);
    kinit_idt(22, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub22, INTERRUPT_GATE);
    kinit_idt(23, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub23, INTERRUPT_GATE);
    kinit_idt(24, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub24, INTERRUPT_GATE);
    kinit_idt(25, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub25, INTERRUPT_GATE);
    kinit_idt(26, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub26, INTERRUPT_GATE);
    kinit_idt(27, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub27, INTERRUPT_GATE);
    kinit_idt(28, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub28, INTERRUPT_GATE);
    kinit_idt(29, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub29, INTERRUPT_GATE);
    kinit_idt(30, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kirq_stub30, INTERRUPT_GATE);
    #pragma endregion
    kload_idt((uint32_t)&kidtr);
}
