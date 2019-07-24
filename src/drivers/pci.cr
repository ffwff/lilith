private struct Pci
  PCI_VENDOR_ID   = 0x00.to_u32
  PCI_DEVICE_ID   = 0x02.to_u32
  PCI_COMMAND     = 0x04.to_u32
  PCI_STATUS      = 0x06.to_u32
  PCI_REVISION_ID = 0x08.to_u32

  PCI_PROG_IF         = 0x09.to_u32
  PCI_SUBCLASS        = 0x0a.to_u32
  PCI_CLASS           = 0x0b.to_u32
  PCI_CACHE_LINE_SIZE = 0x0c.to_u32
  PCI_LATENCY_TIMER   = 0x0d.to_u32
  PCI_HEADER_TYPE     = 0x0e.to_u32
  PCI_BIST            = 0x0f.to_u32
  PCI_BAR0            = 0x10.to_u32
  PCI_BAR1            = 0x14.to_u32
  PCI_BAR2            = 0x18.to_u32
  PCI_BAR3            = 0x1C.to_u32
  PCI_BAR4            = 0x20.to_u32
  PCI_BAR5            = 0x24.to_u32

  PCI_INTERRUPT_LINE = 0x3C.to_u32

  PCI_SECONDARY_BUS = 0x19.to_u32

  PCI_HEADER_TYPE_DEVICE  = 0.to_u32
  PCI_HEADER_TYPE_BRIDGE  = 1.to_u32
  PCI_HEADER_TYPE_CARDBUS = 2.to_u32

  PCI_TYPE_BRIDGE = 0x0604
  PCI_TYPE_SATA   = 0x0106

  PCI_ADDRESS_PORT = 0xCF8.to_u16
  PCI_VALUE_PORT   = 0xCFC.to_u16

  PCI_NONE = 0xFFFF.to_u16

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

  # enumerating PCI buses
  @has_ide = false
  getter has_ide

  def check_function(bus : UInt32, device : UInt32, func : UInt32)
    klass = read_field bus, device, func, PCI_CLASS, 1
    subclass = read_field bus, device, func, PCI_SUBCLASS, 1
    progif = read_field bus, device, func, PCI_PROG_IF, 1
    debug "detected PCI device "
    debug_pci bus, device, func
    debug " "
    debug_pci_device klass, subclass, progif
    debug " "

    # filter functions
    if klass == 0x01 && subclass == 0x01 &&
       (progif == 0x8A || progif == 0x80)
      debug "(ide device)\n"
      @has_ide = true
      return
    end

    debug "\n"
  end

  private def check_device(bus : UInt32, device : UInt32)
    vendor_id = read_field bus, device, 0, PCI_VENDOR_ID, 2
    return if vendor_id == PCI_NONE # device doesn't exist
    func = 0u32
    check_function(bus, device, func)
    header_type = read_field bus, device, 0, PCI_HEADER_TYPE, 1
    if (header_type & 0x80) != 0
      func = 1u32
      while func < 8
        if read_field(bus, device, 0, PCI_VENDOR_ID, 2) != PCI_NONE
          check_function bus, device, func
        end
        func += 1
      end
    end
  end

  private def check_bus(bus : UInt32)
    device = 0u32
    while device < 32
      check_device(bus, device)
      device += 1
    end
  end

  def check_all_buses
    header_type = read_field 0u32, 0u32, 0u32, PCI_HEADER_TYPE, 1
    if (header_type & 0x80) == 0
      # Single PCI host controller
      check_bus 0
    else
      func = 0u32
      while func < 8
        break if read_field(0u32, 0u32, func, PCI_VENDOR_ID, 2) != 0xFFFF
        check_bus func
        func += 1
      end
    end
  end

  # print
  private def debug_pci(slot, device, func)
    return
    VGA.puts "["
    slot.to_s VGA, 16
    VGA.puts ":"
    device.to_s VGA, 16
    VGA.puts "."
    func.to_s VGA, 16
    VGA.puts "]"
  end

  private def debug_pci_device(klass, subclass, progif)
    return
    VGA.puts "("
    klass.to_s VGA, 16
    VGA.puts ":"
    subclass.to_s VGA, 16
    VGA.puts "."
    progif.to_s VGA, 16
    VGA.puts ")"
  end

  private def debug(*args)
    return
    VGA.puts *args
  end
end

PCI = Pci.new
