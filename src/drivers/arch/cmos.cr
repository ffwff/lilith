module CMOS
  extend self

  CMOS_ADDRESS = 0x70u16
  CMOS_DATA    = 0x71u16

  def update_in_process?
    X86.outb(CMOS_ADDRESS, 0x0Au8)
    (X86.inb(CMOS_DATA) & 0x80) != 0
  end

  def get_register(reg)
    X86.outb(CMOS_ADDRESS, reg.to_u8)
    X86.inb(CMOS_DATA)
  end
end
