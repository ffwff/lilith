require "../core/proc.cr"
require "../core/static_array.cr"

IDT_SIZE = 256
IRQ = 0x20
INTERRUPT_GATE = 0x8e
TRAP_GATE = 0x8f
KERNEL_CODE_SEGMENT_OFFSET = 0x08

private lib Kernel

    fun kinit_idtr()
    fun kinit_idt(num : UInt32, selector : UInt16, offset : UInt32, type : UInt16)

end

lib IdtData

    @[Packed]
    struct Registers
        # Pushed by pushad:
        edi, esi, ebp, esp, ebx, edx, ecx, eax : UInt32
        # Interrupt number
        int_no : UInt32
        # Pushed by the processor automatically.
        eip, cs, eflags, useresp, ss : UInt32
    end

end

alias InterruptHandler = ->Nil

module Idt
    extend self

    # initialize
    IRQ_COUNT = 16
    @@irq_handlers = uninitialized InterruptHandler[IRQ_COUNT]
    def initialize
        {% for i in 0...IRQ_COUNT %}
            @@irq_handlers[{{ i }}] = ->{ nil }
        {% end %}
    end

    def init_table
        Kernel.kinit_idtr()
    end

    def init_interrupts
        X86.outb 0x20, 0x11
        X86.outb 0xA0, 0x11
        X86.outb 0x21, 0x20
        X86.outb 0xA1, 0x28
        X86.outb 0x21, 0x04
        X86.outb 0xA1, 0x02
        X86.outb 0x21, 0x01
        X86.outb 0xA1, 0x01
        X86.outb 0x21, 0x0
        X86.outb 0xA1, 0x0
    end

    # handlers
    def irq_handlers; @@irq_handlers; end

    def register_irq(idx : Int, handler : InterruptHandler)
        @@irq_handlers[idx] = handler
    end

    # status
    @[AlwaysInline]
    def enable
        asm("sti")
    end

    @[AlwaysInline]
    def disable
        asm("cli")
    end

end

fun kirq_handler(frame : IdtData::Registers)
    # send EOI signal to PICs
    if frame.int_no >= 8
        # send to slave
        X86.outb 0xA0, 0x20
    end
    # send to master
    X86.outb 0x20, 0x20

    Idt.irq_handlers[frame.int_no].call
end
