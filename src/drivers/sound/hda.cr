module HDA
  extend self

  @@bus = 0u32
  @@device = 0u32
  @@func = 0u32
  @@registers = Pointer(UInt8).null

  @@corb = Pointer(UInt32).null
  @@rirb = Pointer(UInt32).null
  
  def corb_phys
    @@corb.address & ~Paging::IDENTITY_MASK
  end
  
  def rirb_phys
    @@rirb.address & ~Paging::IDENTITY_MASK
  end

  @@corb_idx = 0
  @@corb_size = 0x0

  private def word_reg(offset)
    (@@registers + offset).as(UInt16*)
  end

  private def long_reg(offset)
  end

  private def read_word(offset)
    (@@registers + offset).as(UInt16*).value
  end

  private def write_word(offset, value : UInt16)
    (@@registers + offset).as(UInt16*).value = value
  end

  private def read_long(offset)
    (@@registers + offset).as(UInt32*).value
  end

  private def write_long(offset, value : UInt32)
    (@@registers + offset).as(UInt32*).value = value
  end

  GCTL      = 0x08
  INTCTL    = 0x20
  INTSTS    = 0x24
  WAKEEN    = 0x0C
  STATESTS  = 0x0E

  CORBLBASE = 0x40
  CORBUBASE = 0x44
  CCORBWP   = 0x48
  CCORBRP   = 0x4A
  CORBSIZE  = 0x4E
  CORBCTL   = 0x4C

  RIRBLBASE = 0x50
  RIRBUBASE = 0x54
  RIRBSIZE  = 0x5E
  RIRBCTL   = 0x5C
  RIRBSTS   = 0x5D
  RINTCNT   = 0x5A

  GET_PARAMETER = 0xF00u32

  def corb_entry(data : UInt32, command : UInt32, nidx : UInt32, codec : UInt32)
    (data & 0xFF) | ((command & 0xFFF) << 8) | ((nidx & 0xFF) << 19) | ((codec & 0xF) << 27)
  end

  def init_controller(@@bus : UInt32, @@device : UInt32, @@func : UInt32)
    Console.print "Initializing Intel HDA...\n"

    header_type = PCI.read_field @@bus, @@device, @@func, PCI::PCI_HEADER_TYPE, 1
    PCI.enable_bus_mastering @@bus, @@device, @@func
    phys = PCI.read_base_address(@@bus, @@device, @@func, header_type)

    @@corb = Pointer(UInt32).new(FrameAllocator.claim_with_addr | Paging::IDENTITY_MASK)
    zero_page @@corb.as(UInt8*)
    @@rirb = Pointer(UInt32).new(FrameAllocator.claim_with_addr | Paging::IDENTITY_MASK)
    zero_page @@rirb.as(UInt8*)
    @@registers = Pointer(UInt8).new(phys | Paging::IDENTITY_MASK)
    Paging.alloc_page_pg(@@registers.address, true, false, 4, phys)

    Serial.print @@registers, '\n'
    Serial.print @@corb, '\n'
    Serial.print @@rirb, '\n'

    # reset the device
    write_long GCTL, 0x0
    X86.flush_memory
    while (read_long(GCTL) & 0x1) != 0
      # wait until bit 15 is cleared
    end
    write_long GCTL, 0x1
    X86.flush_memory
    while (read_long(GCTL) & 0x1) == 0
      # wait until bit 15 is cleared
    end

    # codecs
    Serial.print "statests: ", word_reg(STATESTS).value, '\n'

    # set corb address
    write_long CORBLBASE, (corb_phys & 0xFFFF_FFFFu64).to_u32
    write_long CORBUBASE, (corb_phys >> 32).to_u32

    # set rirb address
    write_long RIRBLBASE, (rirb_phys & 0xFFFF_FFFFu64).to_u32
    write_long RIRBUBASE, (rirb_phys >> 32).to_u32

    # set CORB/RIRB size
    set_buffer_size_register CORBSIZE
    set_buffer_size_register RIRBSIZE

    # RIRBSTS
    @@registers[RIRBCTL] = @@registers[RIRBCTL] | 0b1

    # set the Read Pointer Reset bit
    write_long CCORBRP, 0x8000
    X86.flush_memory
    while (read_long(CCORBRP) >> 15) == 0
      # wait until bit 15 is set
    end

    X86.flush_memory
    write_long CCORBRP, 0x0
    X86.flush_memory
    while (read_long(CCORBRP) >> 15) == 1
      # wait until bit 15 is set
    end

    push_corb corb_entry(0x4u32, GET_PARAMETER, 0u32, 0u32)
    
    # set N Response Interrupt Count to 1
    write_word RINTCNT, 0x1

    # enable the RIRB DMA engine
    write_word RIRBCTL, read_word(RIRBCTL) | 0b11

    # enable the CORB DMA engine
    write_word CORBCTL, read_word(CORBCTL) | 0b10


    breakpoint
  end

  def set_buffer_size_register(reg)
    supported_size = (@@registers[reg] & 0b11110000) >> 4
    case supported_size
    when 1
      @@corb_size = 8
      @@registers[reg] = 0b1
    when 2
      @@corb_size = 64
      @@registers[reg] = 0b10
    when 4
      @@corb_size = 1024
      @@registers[reg] = 0b100
    else
      abort "unhandled CORB/RIRB size capability"
    end
  end

  def push_corb(entry : UInt32)
    if @@corb_idx == @@corb_size
      @@corb_idx = 0
    end
    @@corb_idx += 1
    @@corb[@@corb_idx] = entry
    write_word CCORBWP, @@corb_idx.to_u16
  end

  # check pci device
  def pci_device?(vendor_id, device_id)
    vendor_id == 0x8086 && device_id == 0x2668
  end

end
