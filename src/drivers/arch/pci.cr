module PCI
  extend self

  PCI_VENDOR_ID   = 0x00u32
  PCI_DEVICE_ID   = 0x02u32
  PCI_COMMAND     = 0x04u32
  PCI_STATUS      = 0x06u32
  PCI_REVISION_ID = 0x08u32

  PCI_PROG_IF         = 0x09u32
  PCI_SUBCLASS        = 0x0au32
  PCI_CLASS           = 0x0bu32
  PCI_CACHE_LINE_SIZE = 0x0cu32
  PCI_LATENCY_TIMER   = 0x0du32
  PCI_HEADER_TYPE     = 0x0eu32
  PCI_BIST            = 0x0fu32
  PCI_BAR0            = 0x10u32
  PCI_BAR1            = 0x14u32
  PCI_BAR2            = 0x18u32
  PCI_BAR3            = 0x1Cu32
  PCI_BAR4            = 0x20u32
  PCI_BAR5            = 0x24u32

  PCI_INTERRUPT_LINE = 0x3Cu32

  PCI_SECONDARY_BUS = 0x19u32

  PCI_HEADER_TYPE_DEVICE  = 0u32
  PCI_HEADER_TYPE_BRIDGE  = 1u32
  PCI_HEADER_TYPE_CARDBUS = 2u32

  PCI_TYPE_BRIDGE = 0x0604
  PCI_TYPE_SATA   = 0x0106

  PCI_ADDRESS_PORT = 0xCF8u16
  PCI_VALUE_PORT   = 0xCFCu16

  PCI_NONE = 0xFFFFu16

  private def config_address(bus : UInt32, slot : UInt32, func : UInt32, offset : UInt32)
    address = (bus << 16) | (slot << 11) |
              (func << 8) | (offset & 0xfc) | 0x80000000
    X86.outl PCI_ADDRESS_PORT, address
  end

  def read_long(bus : UInt32, slot : UInt32, func : UInt32, field : UInt32)
    config_address bus, slot, func, field
    X86.inl PCI_VALUE_PORT
  end

  def read_word(bus : UInt32, slot : UInt32, func : UInt32, field : UInt32)
    config_address bus, slot, func, field
    X86.inw PCI_VALUE_PORT + (field & 2)
  end

  def read_byte(bus : UInt32, slot : UInt32, func : UInt32, field : UInt32)
    config_address bus, slot, func, field
    X86.inb PCI_VALUE_PORT + (field & 3)
  end

  def read_base_address(bus : UInt32, slot : UInt32, func : UInt32, header_type : Int)
    case header_type
    when 0x0
      config_address bus, slot, func, PCI_BAR0
      X86.inl(PCI_VALUE_PORT).to_u64
    else
      abort "TODO: handle header_type != 0x0"
    end
  end

  def write_long(bus : UInt32, slot : UInt32, func : UInt32, field : UInt32, value : Int)
    config_address bus, slot, func, field
    X86.outl PCI_VALUE_PORT, value.to_u32
  end

  def write_word(bus : UInt32, slot : UInt32, func : UInt32, field : UInt32, value : Int)
    config_address bus, slot, func, field
    X86.outw PCI_VALUE_PORT + (field & 2), value.to_u16
  end

  def write_byte(bus : UInt32, slot : UInt32, func : UInt32, field : UInt32, value : Int)
    config_address bus, slot, func, field
    X86.outb PCI_VALUE_PORT + (field & 3), value.to_u8
  end

  # pci scanning
  private def check_device(bus : UInt32, device : UInt32, &block)
    vendor_id = read_word bus, device, 0, PCI_VENDOR_ID
    return if vendor_id == PCI_NONE # device doesn't exist
    func = 0u32
    yield bus, device, 0u32, vendor_id
    header_type = read_byte bus, device, 0, PCI_HEADER_TYPE
    if (header_type & 0x80) != 0
      func = 1u32
      while func < 8
        if (vendor_id = read_word(bus, device, func, PCI_VENDOR_ID)) != PCI_NONE
          yield bus, device, func, vendor_id
        end
        func += 1
      end
    end
  end

  private def check_bus(bus : UInt32, &block)
    device = 0u32
    while device < 32
      check_device(bus, device) do |bus, device, func, vendor_id|
        yield bus, device, func, vendor_id
      end
      device += 1
    end
  end

  def check_all_buses(&block)
    header_type = read_byte 0u32, 0u32, 0u32, PCI_HEADER_TYPE
    if (header_type & 0x80) == 0
      # Single PCI host controller
      check_bus(0) do |bus, device, func, vendor_id|
        yield bus, device, func, vendor_id
      end
    else
      func = 0u32
      while func < 8
        break if read_word(0u32, 0u32, func, PCI_VENDOR_ID) != 0xFFFF
        check_bus(func) do |bus, device, func, vendor_id|
          yield bus, device, func, vendor_id
        end
        func += 1
      end
    end
  end

  def enable_bus_mastering(bus : UInt32, slot : UInt32, func : UInt32)
    value = read_word bus, slot, func, PCI_COMMAND
    value |= (1 << 2)
    value |= (1 << 0)
    write_word bus, slot, func, PCI_COMMAND, value
  end
end
