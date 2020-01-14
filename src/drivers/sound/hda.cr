module HDA
  extend self

  lib Data
    @[Packed]
    struct BufferDescriptorEntry
      address : UInt64
      length : UInt32
      extra : UInt32
    end

    struct BufferDescriptorList
      entries : BufferDescriptorEntry[256]
    end
  end

  @@bus = 0u32
  @@device = 0u32
  @@func = 0u32
  @@registers = Pointer(UInt8).null

  @@corb = Pointer(UInt32).null
  class_getter corb
  @@corb_idx = 0
  @@corb_size = 0x0

  def corb_phys
    @@corb.address & ~Paging::IDENTITY_MASK
  end

  @@rirb = Pointer(UInt64).null
  class_getter rirb
  @@rirb_idx = 0x0
  @@rirb_size = 0x0

  def rirb_phys
    @@rirb.address & ~Paging::IDENTITY_MASK
  end

  @@bdl = Pointer(Data::BufferDescriptorList).null
  class_getter bdl
  @@bdl_idx = 0x0
  @@bdl_size = 0x0

  def bdl_phys
    @@bdl.address & ~Paging::IDENTITY_MASK
  end

  private def word_reg(offset)
    (@@registers + offset).as(UInt16*)
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

  GCTL     = 0x08
  INTCTL   = 0x20
  INTSTS   = 0x24
  WAKEEN   = 0x0C
  STATESTS = 0x0E

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
  RIRBWP    = 0x58

  BDLLBASE = 0x98
  BDLUBASE = 0x9C

  GET_PARAMETER      = 0xF00u32
  GET_STREAM_FORMAT  = 0xA00u32
  GET_CONFIG_DEFAULT = 0xF1Cu32

  SET_CHANNEL_STREAMID   = 0x706u32
  SET_PIN_WIDGET_CONTROL = 0x707u32

  PAR_NODE_COUNT    = 0x04u32
  PAR_FUNCTION_TYPE = 0x05u32
  PAR_WIDGET_CAP    = 0x09u32

  PINCTL_OUT_EN = 1u32 << 6u32

  def rirb_wp
    @@registers[RIRBWP]
  end

  def corb_entry(data : UInt32, command : UInt32, nidx : UInt32, codec : UInt32)
    (data & 0xFF) | ((command & 0xFFF) << 8) | ((nidx & 0xFF) << 20) | ((codec & 0xF) << 28)
  end

  struct StreamFormat
    def initialize(@data : UInt32)
    end

    def pcm?
      ((@data >> 15) & 0x1) == 0
    end

    def sample_base
      ((@data >> 14) & 0x1) == 0 ? 48 : 44
    end

    def sample_multiplier
      case (@data >> 11) & 0b111
      when 0b000
        1
      when 0b001
        2
      when 0b010
        3
      when 0b011
        4
      else
        1
      end
    end

    def sample_divisor
      ((@data >> 8) & 0b111) + 1
    end

    def sample
      (sample_base * sample_multiplier) // sample_divisor
    end

    def bps
      case (@data >> 4) & 0b11
      when 0b000
        8
      when 0b001
        16
      when 0b010
        20
      when 0b011
        24
      when 0b100
        32
      else
        8
      end
    end

    def channels
      @data & 0b1111
    end

    def to_s(io)
      io.print "PCM, " if pcm?
      io.print sample, "kHz, "
      io.print bps, "-bit, "
      io.print channels, " channels"
    end
  end

  struct DACNode
    @idx : Int32
    getter idx

    @codec : Int32
    getter codec

    def initialize(@idx : Int32, @codec : Int32)
    end

    def stream_format
      StreamFormat.new(HDA.push_corb_and_read(HDA.corb_entry(0, GET_STREAM_FORMAT, @idx.to_u32, @codec.to_u32)).to_u32)
    end
  end

  struct OutNode
    @idx : Int32
    getter idx

    @codec : Int32
    getter codec

    def initialize(@idx : Int32, @codec : Int32)
    end

    def enable
      HDA.push_corb_and_read HDA.corb_entry(PINCTL_OUT_EN, SET_PIN_WIDGET_CONTROL, @idx.to_u32, @codec.to_u32)
    end

    def stream_id=(id)
      HDA.push_corb_and_read HDA.corb_entry(((id.to_u32 & 0x0F) << 4) | 0x0,
        SET_CHANNEL_STREAMID, @idx.to_u32, @codec.to_u32)
    end
  end

  class Codec
    @idx : Int32
    getter idx

    @afg_node = 0
    @dac_node : DACNode
    @out_node : OutNode

    def initialize(@idx : Int32)
      @dac_node = DACNode.new(0, @idx)
      @out_node = OutNode.new(0, @idx)
    end

    def function_type(nidx)
      HDA.push_corb_and_read(HDA.corb_entry(PAR_FUNCTION_TYPE, GET_PARAMETER, nidx, @idx.to_u32)) & 0xFF
    end

    def widget_capability(nidx)
      HDA.push_corb_and_read(HDA.corb_entry(PAR_WIDGET_CAP, GET_PARAMETER, nidx, @idx.to_u32))
    end

    def config_default(nidx)
      HDA.push_corb_and_read(HDA.corb_entry(0, GET_CONFIG_DEFAULT, nidx, @idx.to_u32))
    end

    def node_count(nidx = 0u32)
      response = HDA.push_corb_and_read HDA.corb_entry(PAR_NODE_COUNT, GET_PARAMETER, nidx.to_u32, @idx.to_u32)
      start_node = (response >> 16) & 0xFF
      total_nodes = response & 0xFF
      {start_node, total_nodes}
    end

    def fg_count
      node_count 1u32
    end

    def init_device
      @afg_node = begin
        start_node, total_nodes = node_count
        retidx = nil

        total_nodes.times do |i|
          nidx = (start_node + i).to_u32
          Serial.print "nidx: ", nidx, '\n'
          type = function_type(nidx)
          if type == 0x01
            retidx = nidx.to_i32
            break
          end
        end

        retidx
      end || return

      Serial.print "afg group: ", @afg_node, '\n'

      begin
        start_widget, total_widgets = node_count @afg_node
        Serial.print "widget: ", start_widget, ' ', total_widgets, '\n'
        total_widgets.times do |i|
          nidx = (start_widget + i).to_u32
          cap = widget_capability(nidx)
          type = ((cap >> 20) & 0b111)
          Serial.print "cap: ", cap, " id: ", (cap >> 20) & 0b111, '\n'
          case type
          when 0x0
            @dac_node = DACNode.new(nidx.to_i32, @idx)
            Serial.print "format: ", @dac_node.stream_format, '\n'
          when 0x4
            config = config_default(nidx)
            ctype = (config >> 20) & 0b1111
            if ctype == 0
              @out_node = OutNode.new(nidx.to_i32, @idx)
            end
          end
        end
      end

      @out_node.enable
      @out_node.stream_id = 0
    end
  end

  @@codecs : Array(Codec)? = nil
  class_getter! codecs

  def init_controller(@@bus : UInt32, @@device : UInt32, @@func : UInt32)
    Console.print "Initializing Intel HDA...\n"

    header_type = PCI.read_byte @@bus, @@device, @@func, PCI::PCI_HEADER_TYPE
    PCI.enable_bus_mastering @@bus, @@device, @@func
    phys = PCI.read_base_address(@@bus, @@device, @@func, header_type)

    @@corb = Pointer(UInt32).new(FrameAllocator.claim_with_addr | Paging::IDENTITY_MASK)
    zero_page @@corb.as(UInt8*)
    @@rirb = Pointer(UInt64).new(FrameAllocator.claim_with_addr | Paging::IDENTITY_MASK)
    zero_page @@rirb.as(UInt8*)
    @@bdl = Pointer(Data::BufferDescriptorList).new(FrameAllocator.claim_with_addr | Paging::IDENTITY_MASK)
    zero_page @@bdl.as(UInt8*)
    @@registers = Pointer(UInt8).new(phys | Paging::IDENTITY_MASK)
    Paging.alloc_page(@@registers.address, true, false, 4, phys)

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

    # intctl
    write_long INTCTL, (1u32 << 31u32) | (1u32 << 30u32)
    X86.flush_memory
    if (irq = PCI.read_byte(@@bus, @@device, @@func, PCI::PCI_INTERRUPT_LINE)) == 0
      abort "irq is zero!"
    end
    Idt.register_irq irq, ->irq_handler

    # codecs
    state_sts = word_reg(STATESTS).value & 0x7fff
    return if state_sts == 0
    idx = 0
    while idx < 15
      if (state_sts & 0x1) != 0
        if !@@codecs
          @@codecs = Array(Codec).new
        end
        codecs.push Codec.new(idx)
      end
      state_sts >>= 1
      idx += 1
    end

    # set corb address
    write_long CORBLBASE, (corb_phys & 0xFFFF_FFFFu64).to_u32
    write_long CORBUBASE, (corb_phys >> 32).to_u32

    # set rirb address
    write_long RIRBLBASE, (rirb_phys & 0xFFFF_FFFFu64).to_u32
    write_long RIRBUBASE, (rirb_phys >> 32).to_u32

    # set bdl address
    write_long BDLLBASE, (bdl_phys & 0xFFFF_FFFFu64).to_u32
    write_long BDLUBASE, (bdl_phys >> 32).to_u32

    # set CORB size
    supported_size = (@@registers[CORBSIZE] & 0b11110000) >> 4
    case supported_size
    when 1
      @@corb_size = 2
      @@registers[CORBSIZE] = 0b1
    when 2
      @@corb_size = 16
      @@registers[CORBSIZE] = 0b10
    when 4
      @@corb_size = 256
      @@registers[CORBSIZE] = 0b100
    else
      abort "unhandled CORB size capability"
    end

    # set RIRB size
    supported_size = (@@registers[RIRBSIZE] & 0b11110000) >> 4
    case supported_size
    when 1
      @@rirb_size = 2
      @@registers[RIRBSIZE] = 0b1
    when 2
      @@rirb_size = 16
      @@registers[RIRBSIZE] = 0b10
    when 4
      @@rirb_size = 256
      @@registers[RIRBSIZE] = 0b100
    else
      abort "unhandled RIRB size capability"
    end

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

    # setup the buffer descriptor list

    codecs[0].init_device

    breakpoint
  end

  def push_corb(entry : UInt32)
    @@rirb_updated = false

    if @@corb_idx == @@corb_size
      @@corb_idx = 0
    else
      @@corb_idx += 1
    end
    @@corb[@@corb_idx] = entry
    write_word CCORBWP, @@corb_idx.to_u16

    if @@rirb_idx == @@rirb_size
      @@rirb_idx = 0
    else
      @@rirb_idx += 1
    end
    write_word RINTCNT, @@rirb_idx.to_u16

    # enable the DMA engine
    write_word RIRBCTL, read_word(RIRBCTL) | 0b11
    write_word CORBCTL, 0b10
  end

  def push_corb_and_read(entry : UInt32)
    HDA.push_corb entry
    while !HDA.rirb_updated
      asm("pause")
    end
    HDA.rirb[HDA.rirb_wp]
  end

  @@rirb_updated = false
  class_getter rirb_updated

  def irq_handler
    if (@@registers[RIRBSTS] & 0b1) != 0
      @@rirb_updated = true
      @@registers[RIRBSTS] = @@registers[RIRBSTS] & ~0b1
    end
  end

  # check pci device
  def pci_device?(vendor_id, device_id)
    vendor_id == 0x8086 && device_id == 0x2668
  end
end
