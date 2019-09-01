
module Pit
  extend self

  private PIT_CONST = 1193180
  FREQ = 60
  
  def init_device
    X86.outb(0x43, 0x36)
    divisor = PIT_CONST.unsafe_div(FREQ)
    l = (divisor & 0xFF).to_u8
    h = (divisor.unsafe_shr(8) & 0xFF).to_u8
    X86.outb(0x40, l)
    X86.outb(0x40, h)
  end
end
