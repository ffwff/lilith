#include "arch/idt.h"
#include "arch/mem.h"

// IDT
extern void kload_idt(uint32_t idt_ptr);

static void kinit_idt(uint32_t num, uint16_t select, uint32_t offset, uint16_t type) {
    kidt[num].offset_1 = (offset & 0xffff);
    kidt[num].offset_2 = (offset & 0xffff0000) >> 16;
    kidt[num].selector = select;
    kidt[num].zero = 0;
    kidt[num].type_attr = type;
}

#pragma region bunch of kcpuex
extern void kcpuex0();
extern void kcpuex1();
extern void kcpuex2();
extern void kcpuex3();
extern void kcpuex4();
extern void kcpuex5();
extern void kcpuex6();
extern void kcpuex7();
extern void kcpuex8();
extern void kcpuex9();
extern void kcpuex10();
extern void kcpuex11();
extern void kcpuex12();
extern void kcpuex13();
extern void kcpuex14();
extern void kcpuex15();
extern void kcpuex16();
extern void kcpuex17();
extern void kcpuex18();
extern void kcpuex19();
extern void kcpuex20();
extern void kcpuex21();
extern void kcpuex22();
extern void kcpuex23();
extern void kcpuex24();
extern void kcpuex25();
extern void kcpuex26();
extern void kcpuex27();
extern void kcpuex28();
extern void kcpuex29();
extern void kcpuex30();
extern void kcpuex31();
#pragma endregion

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
    // kcpuex inits
    #if 1
    kinit_idt(0, KERNEL_CODE_SEGMENT_OFFSET,  (uint32_t)kcpuex0  , INTERRUPT_GATE);
    kinit_idt(1, KERNEL_CODE_SEGMENT_OFFSET,  (uint32_t)kcpuex1  , INTERRUPT_GATE);
    kinit_idt(2, KERNEL_CODE_SEGMENT_OFFSET,  (uint32_t)kcpuex2  , INTERRUPT_GATE);
    kinit_idt(3, KERNEL_CODE_SEGMENT_OFFSET,  (uint32_t)kcpuex3  , INTERRUPT_GATE);
    kinit_idt(4, KERNEL_CODE_SEGMENT_OFFSET,  (uint32_t)kcpuex4  , INTERRUPT_GATE);
    kinit_idt(5, KERNEL_CODE_SEGMENT_OFFSET,  (uint32_t)kcpuex5  , INTERRUPT_GATE);
    kinit_idt(6, KERNEL_CODE_SEGMENT_OFFSET,  (uint32_t)kcpuex6  , INTERRUPT_GATE);
    kinit_idt(7, KERNEL_CODE_SEGMENT_OFFSET,  (uint32_t)kcpuex7  , INTERRUPT_GATE);
    kinit_idt(8, KERNEL_CODE_SEGMENT_OFFSET,  (uint32_t)kcpuex8  , INTERRUPT_GATE);
    kinit_idt(9, KERNEL_CODE_SEGMENT_OFFSET,  (uint32_t)kcpuex9  , INTERRUPT_GATE);
    kinit_idt(10, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kcpuex10 , INTERRUPT_GATE);
    kinit_idt(11, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kcpuex11 , INTERRUPT_GATE);
    kinit_idt(12, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kcpuex12 , INTERRUPT_GATE);
    kinit_idt(13, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kcpuex13 , INTERRUPT_GATE);
    kinit_idt(14, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kcpuex14 , INTERRUPT_GATE);
    kinit_idt(15, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kcpuex15 , INTERRUPT_GATE);
    kinit_idt(16, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kcpuex16 , INTERRUPT_GATE);
    kinit_idt(17, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kcpuex17 , INTERRUPT_GATE);
    kinit_idt(18, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kcpuex18 , INTERRUPT_GATE);
    kinit_idt(19, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kcpuex19 , INTERRUPT_GATE);
    kinit_idt(20, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kcpuex20 , INTERRUPT_GATE);
    kinit_idt(21, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kcpuex21 , INTERRUPT_GATE);
    kinit_idt(22, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kcpuex22 , INTERRUPT_GATE);
    kinit_idt(23, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kcpuex23 , INTERRUPT_GATE);
    kinit_idt(24, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kcpuex24 , INTERRUPT_GATE);
    kinit_idt(25, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kcpuex25 , INTERRUPT_GATE);
    kinit_idt(26, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kcpuex26 , INTERRUPT_GATE);
    kinit_idt(27, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kcpuex27 , INTERRUPT_GATE);
    kinit_idt(28, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kcpuex28 , INTERRUPT_GATE);
    kinit_idt(29, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kcpuex29 , INTERRUPT_GATE);
    kinit_idt(30, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kcpuex30 , INTERRUPT_GATE);
    kinit_idt(31, KERNEL_CODE_SEGMENT_OFFSET, (uint32_t)kcpuex31 , INTERRUPT_GATE);
    #endif

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
