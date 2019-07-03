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

module Idt
    extend self

    def init_table
        Kernel.kinit_idtr()
    end

    @[AlwaysInline]
    def enable
        asm("sti")
    end

    @[AlwaysInline]
    def disable
        asm("cli")
    end

end

fun kirq_handler
    Serial.puts "."
end
