module Serial 
  extend self
  include OutputDriver

  private PORT = 0x3F8
  def init_device
    X86.outb((PORT + 1).to_u16, 0x00u8) # Disable all interrupts
    X86.outb((PORT + 3).to_u16, 0x80u8) # Enable DLAB (set baud rate divisor)
    X86.outb((PORT + 0).to_u16, 0x03u8) # Set divisor to 3 (lo byte) 38400 baud
    X86.outb((PORT + 1).to_u16, 0x00u8) #                  (hi byte)
    X86.outb((PORT + 3).to_u16, 0x03u8) # 8 bits, no parity, one stop bit
    X86.outb((PORT + 2).to_u16, 0xC7u8) # Enable FIFO, clear them, with 14-byte threshold
    X86.outb((PORT + 4).to_u16, 0x0Bu8) # IRQs enabled, RTS/DSR set
  end

  def available?
    X86.inb((PORT + 5).to_u16) & 1 == 0
  end

  def transmit_empty?
    (X86.inb((PORT + 5).to_u16) & 0x20) == 0
  end

  def putc(a : UInt8)
    while transmit_empty?
      asm("pause")
    end
    X86.outb(PORT.to_u16, a)
  end
end
