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
    address = bus.unsafe_shl(16) | slot.unsafe_shl(11) |
              func.unsafe_shl(8) | (offset & 0xfc) | 0x80000000
    X86.outl PCI_ADDRESS_PORT, address
  end

  def read_field(bus : UInt32, slot : UInt32, func : UInt32, field : UInt32, size)
    config_address bus, slot, func, field
    case size
    when 4
      X86.inl PCI_VALUE_PORT
    when 2
      X86.inw PCI_VALUE_PORT + (field & 2)
    when 1
      X86.inb PCI_VALUE_PORT + (field & 3)
    else
      0xFFFF
    end
  end

  # pci scanning
  private def check_device(bus : UInt32, device : UInt32, &block)
    vendor_id = read_field bus, device, 0, PCI_VENDOR_ID, 2
    return if vendor_id == PCI_NONE # device doesn't exist
    func = 0u32
    yield bus, device, 0u32, vendor_id
    header_type = read_field bus, device, 0, PCI_HEADER_TYPE, 1
    if (header_type & 0x80) != 0
      func = 1u32
      while func < 8
        if (vendor_id = read_field(bus, device, func, PCI_VENDOR_ID, 2)) != PCI_NONE
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
    header_type = read_field 0u32, 0u32, 0u32, PCI_HEADER_TYPE, 1
    if (header_type & 0x80) == 0
      # Single PCI host controller
      check_bus(0) do |bus, device, func, vendor_id|
        yield bus, device, func, vendor_id
      end
    else
      func = 0u32
      while func < 8
        break if read_field(0u32, 0u32, func, PCI_VENDOR_ID, 2) != 0xFFFF
        check_bus(func) do |bus, device, func, vendor_id|
          yield bus, device, func, vendor_id
        end
        func += 1
      end
    end
  end
end