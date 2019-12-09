module PIC
  extend self

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

  # sets the PIC mask
  def enable(irq)
    if irq >= 8
      imr = X86.inb 0xA1
      imr &= ~(1 << (irq - 8))
      X86.outb 0xA1, imr
    else
      imr = X86.inb 0x21
      imr &= ~(1 << irq)
      X86.outb 0x21, imr
    end
  end

  # clears the PIC mask
  def disable(irq)
    if irq >= 8
      imr = X86.inb 0xA1
      imr |= 1 << (irq - 8)
      X86.outb 0xA1, imr
    else
      imr = X86.inb 0x21
      imr |= 1 << irq
      X86.outb 0x21, imr
    end
  end

  def eoi(irq : Int)
    # send EOI signal to PICs
    if irq >= 8
      # send to slave
      X86.outb 0xA0, 0x20
    end
    # send to master
    X86.outb 0x20, 0x20
  end

end
