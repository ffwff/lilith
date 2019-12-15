module Pit
  extend self

  private PIT_CONST      = 1193180
  FREQUENCY      =    1000 # Hz
  USECS_PER_TICK = 1_000_000 // FREQUENCY

  def init_device
    Idt.register_irq 0, ->callback

    X86.outb(0x43, 0x36)
    divisor = PIT_CONST // FREQUENCY
    l = (divisor & 0xFF).to_u8
    h = ((divisor >> 8) & 0xFF).to_u8
    X86.outb(0x40, l)
    X86.outb(0x40, h)
  end

  @@ticks = 0u64

  def callback
    @@ticks += 1
    if (@@ticks % FREQUENCY) == 0
      Time.stamp += 1
    end
    Time.usecs_since_boot += USECS_PER_TICK
  end
end
