private lib Kernel
  # T13/1699-D Revision 3f
  # 7.16 IDENTIFY DEVICE, pg 90
  # also see ftp://ftp.seagate.com/acrobat/reference/111-1c.pdf
  @[Packed]
  struct AtaIdentify
    flags : UInt16
    unused1 : UInt16[9]
    serial : UInt8[20]
    unused2 : UInt16[3]
    firmware : UInt8[8]
    model : UInt8[40]
    # Maximum number of logical sectors that shall be transferred per DRQ data block on READ/WRITE MULTIPLE commands
    sectors_per_int : UInt16
    unused3 : UInt16
    capabilities : UInt16[2]
    unused4 : UInt16[2]
    valid_ext_data : UInt16
    unused5 : UInt16[5]
    size_of_rw_mult : UInt16
    # Total number of user addressable logical sectors
    sectors_28 : UInt32
    unused6 : UInt16[38]
    # Total Number of User Addressable Sectors for the 48-bit Address feature set
    sectors_48 : UInt64
    unused7 : UInt16[152]
  end
end

private module Ata
  extend self

  # statuses
  SR_BSY  = 0x80
  SR_DRDY = 0x40
  SR_DF   = 0x20
  SR_DSC  = 0x10
  SR_DRQ  = 0x08
  SR_CORR = 0x04
  SR_IDX  = 0x02
  SR_ERR  = 0x01

  # error codes
  ER_BBK   = 0x80
  ER_UNC   = 0x40
  ER_MC    = 0x20
  ER_IDNF  = 0x10
  ER_MCR   = 0x08
  ER_ABRT  = 0x04
  ER_TK0NF = 0x02
  ER_AMNF  = 0x01

  # ata commands
  CMD_READ_PIO        = 0x20u8
  CMD_READ_PIO_EXT    = 0x24u8
  CMD_READ_DMA        = 0xC8u8
  CMD_READ_DMA_EXT    = 0x25u8
  CMD_WRITE_PIO       = 0x30u8
  CMD_WRITE_PIO_EXT   = 0x34u8
  CMD_WRITE_DMA       = 0xCAu8
  CMD_WRITE_DMA_EXT   = 0x35u8
  CMD_CACHE_FLUSH     = 0xE7u8
  CMD_CACHE_FLUSH_EXT = 0xEAu8
  CMD_PACKET          = 0xA0u8
  CMD_IDENTIFY_PACKET = 0xA1u8
  CMD_IDENTIFY        = 0xECu8

  # atapi commands
  ATAPI_CMD_READ  = 0xA8u8
  ATAPI_CMD_EJECT = 0x1Bu8

  # identifiers
  IDENT_DEVICETYPE   =   0
  IDENT_CYLINDERS    =   2
  IDENT_HEADS        =   6
  IDENT_SECTORS      =  12
  IDENT_SERIAL       =  20
  IDENT_MODEL        =  54
  IDENT_CAPABILITIES =  98
  IDENT_FIELDVALID   = 106
  IDENT_MAX_LBA      = 120
  IDENT_COMMANDSETS  = 164
  IDENT_MAX_LBA_EXT  = 200

  #
  MASTER = 0x00
  SLAVE  = 0x01

  #
  REG_DATA       = 0x00u16
  REG_ERROR      = 0x01u16
  REG_FEATURES   = 0x01u16
  REG_SECCOUNT0  = 0x02u16
  REG_LBA0       = 0x03u16
  REG_LBA1       = 0x04u16
  REG_LBA2       = 0x05u16
  REG_HDDEVSEL   = 0x06u16
  REG_COMMAND    = 0x07u16
  REG_STATUS     = 0x07u16
  REG_SECCOUNT1  = 0x08u16
  REG_LBA3       = 0x09u16
  REG_LBA4       = 0x0Au16
  REG_LBA5       = 0x0Bu16
  REG_CONTROL    = 0x0Cu16
  REG_ALTSTATUS  = 0x0Cu16
  REG_DEVADDRESS = 0x0Du16

  # channels
  CHAN_PRIMARY   = 0x00
  CHAN_SECONDARY = 0x01

  # directions
  DIR_READ  = 0x00
  DIR_WRITE = 0x01

  SCSI_PACKET_SIZE = 12

  def read_cyl(bus)
    cl = X86.inb(bus + REG_LBA1)
    ch = X86.inb(bus + REG_LBA2)
    {cl, ch}
  end

  # drive = 0 => primary
  # drive = 1 => secondary
  def select(bus, slave = 0u8)
    X86.outb(bus + REG_HDDEVSEL, 0xA0.to_u8 | (slave << 4))
  end

  def identify(bus)
    X86.outb(bus + REG_COMMAND, CMD_IDENTIFY)
  end

  def identify_packet(bus)
    X86.outb(bus + REG_COMMAND, CMD_IDENTIFY_PACKET)
  end

  def status(bus)
    X86.inb(bus + REG_COMMAND)
  end

  # wait functions
  def wait_io(bus)
    4.times { |i| X86.inb(bus + REG_ALTSTATUS) }
  end

  def wait_ready(bus)
    while ((status = X86.inb(bus + REG_STATUS)) & SR_BSY) != 0
    end
    status
  end

  # Wait for ATAPI command to be finished
  # See: http://lateblt.tripod.com/atapi.htm
  def wait_atapi(bus)
    while ((status = X86.inb(bus + REG_STATUS)) & SR_BSY) != 0 &&
          (status & SR_DRQ) != 0
    end
    status
  end

  def wait(bus, advanced = false)
    wait_io bus
    status = wait_ready bus
    if advanced
      if (status & SR_ERR) != 0 ||
         (status & SR_DF)  != 0 ||
         (status & SR_DRQ) == 0
        return false
      end
    end
    true
  end

  # read functions
  def read(sector : UInt64, bus, slave)
    # PIO 24-bit
    wait_ready bus

    X86.outb(bus + REG_HDDEVSEL, (0xe0 | (slave << 4) |
                                  ((sector & 0x0f000000) >> 24)).to_u8)
    X86.outb(bus + REG_FEATURES, 0x00)
    X86.outb(bus + REG_SECCOUNT0, 1)
    X86.outb(bus + REG_LBA0, (sector & 0x000000ff).to_u8)
    X86.outb(bus + REG_LBA1, ((sector & 0x0000ff00) >> 8).to_u8)
    X86.outb(bus + REG_LBA2, ((sector & 0x00ff0000) >> 16).to_u8)
    X86.outb(bus + REG_COMMAND, CMD_READ_PIO)
  end

  def read_atapi(sector, bus, slave)
    # Almost all ATAPI devices have a sector size of 2048
    sector_size = 2048

    # SCSI packet
    packet = uninitialized UInt8[SCSI_PACKET_SIZE]
    packet[0] = ATAPI_CMD_READ
    packet[1] = 0x0u8
    packet[2] = ((sector >> 24) & 0xFF).to_u8
    packet[3] = ((sector >> 16) & 0xFF).to_u8
    packet[4] = ((sector >> 8)  & 0xFF).to_u8
    packet[5] = ((sector >> 0)  & 0xFF).to_u8
    packet[6] = 0x0u8
    packet[7] = 0x0u8
    packet[8] = 0x0u8
    packet[9] = 0x1u8 # number of sectors
    packet[10] = 0x0u8
    packet[11] = 0x0u8

    wait_ready bus

    X86.outb(bus + REG_HDDEVSEL, (slave << 4).to_u8)
    wait_io bus

    X86.outb(bus + REG_FEATURES, 0x00)
    X86.outb(bus + REG_LBA0, (sector_size & 0xFF).to_u8)
    X86.outb(bus + REG_LBA1, (sector_size >> 8).to_u8)
    X86.outb(bus + REG_COMMAND, CMD_PACKET)

    return unless wait(bus, true)

    6.times do |i|
      packet.to_unsafe.as(UInt16*)[i]
    end

    # read alternate status and ignore it
    X86.inb(bus + REG_ALTSTATUS)
  end

  def flush_cache(bus)
    X86.outb(bus + REG_COMMAND, CMD_CACHE_FLUSH)
  end

  # irq handler
  def irq_handler(bus)
    X86.inb(bus + REG_STATUS)
  end
end

private DISK_PORT_PRIMARY   = 0x1F0u16
private CMD_PORT_PRIMARY    = 0x3F6u16
private DISK_PORT_SECONDARY = 0x170u16
private CMD_PORT_SECONDARY  = 0x3F4u16

class AtaDevice
  def disk_port
    @primary ? DISK_PORT_PRIMARY : DISK_PORT_SECONDARY
  end

  def cmd_port
    @primary ? CMD_PORT_PRIMARY : CMD_PORT_SECONDARY
  end

  #
  getter primary, slave
  @name : GcString? = nil
  getter name

  enum Type
    Ata
    Atapi
  end
  @type = Type::Ata
  getter type

  # NOTE: idx must be between 0..3
  def initialize(@primary = true, @slave = 0)
  end

  #
  def init_device
    X86.outb disk_port + 1, 1
    X86.outb disk_port + 0x306, 0

    Ata.select disk_port, @slave
    Ata.wait_io disk_port

    Ata.identify disk_port
    Ata.wait_io disk_port

    cl, ch = Ata.read_cyl(disk_port)
    if cl == 0xFF && ch == 0xFF
      return false
    elsif (cl == 0x00 && ch == 0x00) || (cl == 0x3C && ch == 0xC3)
      @type = Type::Ata
    elsif (cl == 0x14 && ch == 0xEB) || (cl == 0x69 && ch == 0x96)
      @type = Type::Atapi
    end

    case @type
    when Type::Ata
      name = GcString.new "hd"
      name << (Ide.next_hd_idx + '0'.ord).to_u8
    when Type::Atapi
      name = GcString.new "cdrom"
      name << (Ide.next_cdrom_idx + '0'.ord).to_u8
    end
    @name = name

    # read device identifier
    device = Pointer(Kernel::AtaIdentify).mmalloc

    case @type
    when Type::Ata
      Ata.identify disk_port
      Ata.wait_io disk_port

      status = Ata.status disk_port
      debug "status: ", status, '\n'
      if status == 0
        # cleanup
        device.mfree
        return false
      end
    when Type::Atapi
      Ata.identify_packet disk_port
      Ata.wait_io disk_port

      status = Ata.status disk_port
      debug "status: ", status, '\n'
      if status == 0
        # cleanup
        device.mfree
        return false
      end
    end

    buf = device.as(UInt16*)
    256.times do |i|
      buf[i] = X86.inw disk_port
    end

    # fix model name from endianness
    {% for key in ["serial", "firmware", "model"] %}
      {% key = key.id %}
      i = 0
      while i < device.value.{{ key }}.size
        device.value.{{ key }}[i], device.value.{{ key }}[i+1] = \
        device.value.{{ key }}[i+1], device.value.{{ key }}[i]
        i += 2
      end
    {% end %}
    Serial.puts "Type: ", @type, '\n'
    Serial.puts "Detected: "
    device.value.model.each do |ch|
      Serial.puts ch.unsafe_chr
    end
    Serial.puts "\n"

    # cleanup
    device.mfree
    true
  end

  @lock = Spinlock.new
  def read_sector(ptr, sector : UInt64)
    panic "can't access atapi" if @type == Type::Atapi

    retval = true
    @lock.with do
      Ata.read sector, disk_port, slave
      # poll
      if !Ata.wait(disk_port, true)
        retval = false
        break
      end
      # read from sector
      256.times do |i|
        ptr[i] = X86.inw disk_port
      end
    end

    retval
  end

  #
  def debug(*args)
    Console.puts *args
  end
end

module Ide
  extend self

  @@hd_idx = 0
  @@cdrom_idx = 0

  def next_hd_idx
    idx = @@hd_idx
    @@hd_idx += 1
    idx
  end

  def next_cdrom_idx
    idx = @@cdrom_idx
    @@cdrom_idx += 1
    idx
  end

  def device(idx)
    @@devices.not_nil![idx].not_nil!
  end

  def init_controller
    @@devices = GcArray(AtaDevice?).new 4
    devices = @@devices.not_nil!
    devices[0] = AtaDevice.new(true, 0)
    devices[1] = AtaDevice.new(true, 1)
    devices[2] = AtaDevice.new(false, 0)
    devices[3] = AtaDevice.new(false, 1)

    Idt.register_irq 14, ->ata_primary_irq_handler
    Idt.register_irq 15, ->ata_secondary_irq_handler
    @@devices.not_nil!.size.times do |idx|
      unless device(idx).init_device
        devices[idx] = nil
      end
    end
  end

  # interrupts
  def ata_primary_irq_handler
    Ata.irq_handler DISK_PORT_PRIMARY
  end

  def ata_secondary_irq_handler
    Ata.irq_handler DISK_PORT_SECONDARY
  end

  # check pci device
  def pci_device?(vendor_id, device_id)
    (vendor_id == 0x8086) && (device_id == 0x7010 || device_id == 0x7111)
  end
end
