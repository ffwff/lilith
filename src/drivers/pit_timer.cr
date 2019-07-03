require "../mem/idt.cr"

private PIT_TIME = 1193180

struct PitInstance

    def initialize
        #Idt.init_irq 0, (->callback)
        X86.outb(0x43, 0x36)
        divisor = PIT_TIME.unsafe_div(50)
        l = (divisor & 0xFF).to_u8
        h = (divisor.unsafe_shr(8) & 0xFF).to_u8
        X86.outb(0x40, l)
        X86.outb(0x40, h)
    end

    @[Naked]
    def callback
        asm("pusha")
        Serial.puts "tick"
        asm("popa; leave; iret")
    end

end