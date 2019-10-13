module BGA
  extend self

  INDEX_ID          = 0u16
  INDEX_XRES        = 1u16
  INDEX_YRES        = 2u16
  INDEX_BPP         = 3u16
  INDEX_ENABLE      = 4u16
  INDEX_BANK        = 5u16
  INDEX_VIRT_WIDTH  = 6u16
  INDEX_VIRT_HEIGHT = 7u16
  INDEX_X_OFFSET    = 8u16
  INDEX_Y_OFFSET    = 9u16

  INDEX_PORT = 0x1CEu16
  DATA_PORT  = 0x1CFu16

  def init_controller(bus, device, func)
    X86.outw(INDEX_PORT, 0x0)
    i = X86.inw(DATA_PORT)
    return unless 0xB0C0 <= i && i <= 0xB0C6
    X86.outw(DATA_PORT, 0xB0C4)
    i = X86.inw(DATA_PORT)

    width, height = set_resolution(1280, 720)
    size = width * height * 4
    phys = Pointer(UInt32).new(PCI.read_field(bus, device, func, PCI::PCI_BAR0, 4).to_u64)
    virt = Pointer(UInt32).new(phys.address | PTR_IDENTITY_MASK)
    Paging.alloc_page_pg(virt.address, true, false, size.div_ceil(0x1000).to_usize, phys.address)
    FbdevState.lock do |state|
      state.init_device(width, height, virt)
    end
  end

  def pci_device?(vendor_id, device_id)
    (vendor_id == 0x1234 && device_id == 0x1111) ||
      (vendor_id == 0x80EE && device_id == 0xBEEF) ||
      (vendor_id == 0x10de && device_id == 0x0a20)
  end

  # resolution
  def set_resolution(w : UInt16, h : UInt16)
    # disable vbe extensions
    X86.outw(INDEX_PORT, INDEX_ENABLE)
    X86.outw(DATA_PORT, 0)
    # set width
    X86.outw(INDEX_PORT, INDEX_XRES)
    X86.outw(DATA_PORT, w)
    # set height
    X86.outw(INDEX_PORT, INDEX_YRES)
    X86.outw(DATA_PORT, h)
    # bpp to 32
    X86.outw(INDEX_PORT, INDEX_BPP)
    X86.outw(DATA_PORT, 32)
    # virt height
    X86.outw(INDEX_PORT, INDEX_VIRT_HEIGHT)
    X86.outw(DATA_PORT, 4096)
    # enable
    X86.outw(INDEX_PORT, INDEX_ENABLE)
    X86.outw(DATA_PORT, 1)

    # check if w changed
    X86.outw(INDEX_PORT, INDEX_XRES)
    w = X86.inw(DATA_PORT)

    {w.to_i32, h.to_i32}
  end
end
