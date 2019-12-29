module CMOS
  extend self

  ADDRESS = 0x70u16
  DATA    = 0x71u16

  # Checks if the RTC's update in progress flag is set.
  def update_in_process?
    X86.outb(ADDRESS, 0x0Au8)
    (X86.inb(DATA) & 0x80) != 0
  end

  # Returns the value in the CMOS register `reg`.
  def get_register(reg)
    X86.outb(ADDRESS, reg.to_u8)
    X86.inb(DATA)
  end
end
