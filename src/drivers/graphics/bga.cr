module BGA
  
  def self.init_controller
    X86.outw(0x1CE, 0x0)
    i = X86.inw(0x1CF)
    return unless 0xB0C0 <= i <= 0xB0C6
  end

  def self.pci_device?(vendor_id, device_id)
    (vendor_id == 0x1234 && device_id == 0x1111) ||
    (vendor_id == 0x80EE && device_id == 0xBEEF) ||
    (vendor_id == 0x10de && device_id == 0x0a20)
  end

end