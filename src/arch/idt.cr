# TODO: figure out how to port idt.c over without crashing
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
        # Data segment selector
        ds : UInt16
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

    # interrupt must happen in user mode
    if frame.int_no == 0 && frame.cs == 0x1B && !Multiprocessing.current_process.nil?
        # preemptive multitasking...
        # get the pointer to the literal frame argument
        esp = 0u32
        asm("mov %esp, $0;" : "=r"(esp) :: "volatile")
        # save current frame
        current_process = Multiprocessing.current_process.not_nil!
        current_process.frame = frame
        # next
        next_process = Multiprocessing.next_process.not_nil!
        if next_process.frame.nil?
            next_process.new_frame
        end
        process_frame = next_process.frame.not_nil!
        {% for id in [
            "ds",
            "edi", "esi", "ebp", "esp", "ebx", "edx", "ecx", "eax",
            "eip", "cs", "eflags", "useresp", "ss"
        ] %}
        frame.{{ id.id }} = process_frame.{{ id.id }}
        {% end %}
        # Serial.puts "frame: ", Pointer(Void).new(frame.eip.to_u64), "\n"

        dir = next_process.not_nil!.phys_page_dir # this must be stack allocated
        # because it's placed in the virtual kernel heap
        panic "page dir is nil" if dir == 0
        Paging.disable
        Paging.current_page_dir = Pointer(PageStructs::PageDirectory).new(dir.to_u64)
        Paging.enable
    end

    if Idt.irq_handlers[frame.int_no].pointer.null?
        Serial.puts "no handler for ", frame.int_no, "\n"
        return 0
    else
        Idt.irq_handlers[frame.int_no].call
    end
end
