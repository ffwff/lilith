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
    (@@registers + offset).as(UInt32*)
  end

  GCTL      = 0x08
  INTCTL    = 0x20

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

  GET_PARAMETER = 0xF00

  def init_controller(@@bus : UInt32, @@device : UInt32, @@func : UInt32)
    Console.print "Initializing Intel HDA...\n"

    header_type = PCI.read_field @@bus, @@device, @@func, PCI::PCI_HEADER_TYPE, 1
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
    long_reg(GCTL).value = 0x1

    # set corb address
    long_reg(CORBLBASE).value = (corb_phys & 0xFFFF_FFFFu64).to_u32
    long_reg(CORBUBASE).value = (corb_phys >> 32).to_u32

    # set rirb address
    long_reg(RIRBLBASE).value = (rirb_phys & 0xFFFF_FFFFu64).to_u32
    long_reg(RIRBUBASE).value = (rirb_phys >> 32).to_u32

    # set CORB/RIRB size
    set_buffer_size_register CORBSIZE
    set_buffer_size_register RIRBSIZE

    # RIRBSTS
    @@registers[RIRBCTL] = @@registers[RIRBCTL] | 0b1

    push_corb 0xdeadbeefu32
    
    breakpoint

    # set the Read Pointer Reset bit
    word_reg(CCORBRP).value = 0x8000
    while (word_reg(CCORBRP).value >> 15) == 0
      # wait until bit 15 is set
    end
    X86.flush_memory
    word_reg(CCORBRP).value = 0x0
    while (word_reg(CCORBRP).value >> 15) == 1
      # wait until bit 15 is clear
    end

    # set N Response Interrupt Count to 1
    word_reg(RINTCNT).value = 0x1

    # enable the CORB DMA engine
    word_reg(CORBCTL).value = word_reg(CORBCTL).value | 0b10
    X86.flush_memory
    abort "CORB DMA engine not enabled" if (word_reg(CORBCTL).value & 0b10) == 0

    # enable the RIRB DMA engine
    word_reg(RIRBCTL).value = word_reg(RIRBCTL).value | 0b11


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
    word_reg(CCORBWP).value = @@corb_idx.to_u16
  end

  # check pci device
  def pci_device?(vendor_id, device_id)
    vendor_id == 0x8086 && device_id == 0x2668
  end

end
