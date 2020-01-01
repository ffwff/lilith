module Ata
  extend self

  lib Data
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

  DISK_PORT_PRIMARY   = 0x1F0u16
  CMD_PORT_PRIMARY    = 0x3F6u16
  DISK_PORT_SECONDARY = 0x170u16
  CMD_PORT_SECONDARY  = 0x3F4u16

  def read_cyl(bus)
    cl = X86.inb(bus + REG_LBA1)
    ch = X86.inb(bus + REG_LBA2)
    {cl, ch}
  end

  # drive = 0 => primary
  # drive = 1 => secondary
  def select(bus, slave)
    devsel = 0xA0
    if slave
      devsel |= 1 << 4
    end
    X86.outb(bus + REG_HDDEVSEL, devsel.to_u8)
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
  def wait_io(bus, n = 4)
    n.times do
      X86.inb(bus + REG_ALTSTATUS)
    end
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
         (status & SR_DF) != 0 ||
         (status & SR_DRQ) == 0
        return false
      end
    end
    true
  end

  def devsel(slave)
    retval = 0xe0
    if slave
      retval |= 1 << 4
    end
    retval
  end

  # read functions
  def read(sector : UInt64, bus, slave, nsectors = 1)
    # PIO 24-bit
    wait_ready bus

    X86.outb(bus + REG_HDDEVSEL, (devsel(slave) |
                                  ((sector & 0x0f000000) >> 24)).to_u8)
    X86.outb(bus + REG_FEATURES, 0x00)
    X86.outb(bus + REG_SECCOUNT0, nsectors)
    X86.outb(bus + REG_LBA0, (sector & 0x000000ff).to_u8)
    X86.outb(bus + REG_LBA1, ((sector & 0x0000ff00) >> 8).to_u8)
    X86.outb(bus + REG_LBA2, ((sector & 0x00ff0000) >> 16).to_u8)
    X86.outb(bus + REG_COMMAND, CMD_READ_PIO)
  end

  def read_dma(sector : UInt64, bus, control, slave, nsectors = 1)
    Ide.prdt_ptr.value.size = 512 * nsectors

    # reset bus master
    X86.outb(Ide.bus_master, 0u8)
    # write PRDT location
    X86.outl(Ide.bus_master + 4, Ide.prdt_ptr_phys.to_u32)
    # clear irq/err flags
    X86.outb(Ide.bus_master + 2, X86.inb(Ide.bus_master + 2) | 0x6)
    # transfer direction
    X86.outb(Ide.bus_master, 0x8)

    wait_ready bus

    X86.outb(control, 0)
    X86.outb(bus + REG_HDDEVSEL, (devsel(slave) |
                                  ((sector & 0x0f000000) >> 24)).to_u8)
    X86.outb(bus + REG_FEATURES, 0x00)
    X86.outb(bus + REG_SECCOUNT0, nsectors)
    X86.outb(bus + REG_LBA0, (sector & 0x000000ff).to_u8)
    X86.outb(bus + REG_LBA1, ((sector & 0x0000ff00) >> 8).to_u8)
    X86.outb(bus + REG_LBA2, ((sector & 0x00ff0000) >> 16).to_u8)

    X86.outb(bus + REG_COMMAND, CMD_READ_DMA)
    wait_io bus

    # start bus master
    X86.outb(Ide.bus_master, 0x9)
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
    packet[4] = ((sector >> 8) & 0xFF).to_u8
    packet[5] = ((sector >> 0) & 0xFF).to_u8
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

  def flush_dma
    X86.outb(Ide.bus_master + 2, X86.inb(Ide.bus_master + 2) | 0x6)
  end

  def flush_cache(bus)
    X86.outb(bus + REG_COMMAND, CMD_CACHE_FLUSH)
  end

  # irq handler
  @@interrupted = false
  class_property interrupted

  def irq_handler(bus)
    # Serial.print "irq", Idt.switch_processes, "!\n"
    status = X86.inb(bus + REG_STATUS)
    if (status & SR_ERR) != 0
      err = X86.inb(bus + REG_ERROR)
      Serial.print "error: ", err, '\n'
    end
    @@interrupted = true
  end

  class Device
    def disk_port
      @primary ? Ata::DISK_PORT_PRIMARY : Ata::DISK_PORT_SECONDARY
    end

    def cmd_port
      @primary ? Ata::CMD_PORT_PRIMARY : Ata::CMD_PORT_SECONDARY
    end

    getter primary, slave

    @name : String? = nil
    getter! name

    @can_dma = false

    enum Type
      Ata
      Atapi
    end
    @type = Type::Ata
    getter type

    def irq
      @primary ? 14 : 15
    end

    # NOTE: idx must be between 0..3
    def initialize(@primary = true, @slave = false)
    end

    # initialize device
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
        builder = String::Builder.new 4
        builder << "hd"
        builder.write_byte (Ide.next_hd_idx + '0'.ord).to_u8
      when Type::Atapi
        builder = String::Builder.new 7
        builder << "cdrom"
        builder.write_byte (Ide.next_hd_idx + '0'.ord).to_u8
      else
        abort "unhandled ata type: ", @type
      end
      @name = builder.to_s

      # read device identifier
      device = Pointer(Ata::Data::AtaIdentify).malloc_atomic

      case @type
      when Type::Ata
        Ata.identify disk_port
        Ata.wait_io disk_port

        status = Ata.status disk_port
        # Serial.print "status: ", status, '\n'
        if status == 0
          # cleanup
          return false
        end
      when Type::Atapi
        Ata.identify_packet disk_port
        Ata.wait_io disk_port

        status = Ata.status disk_port
        # Serial.print "status: ", status, '\n'
        if status == 0
          # cleanup
          return false
        end
      end

      buf = device.as(UInt16*)
      256.times do |i|
        buf[i] = X86.inw disk_port
      end

      if (device.value.capabilities[0] & (1 << 8)) != 0
        @can_dma = true
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

      true
    end

    def dma_buffer?
      if @can_dma
        Ide.dma_buffer
      end
    end

    def read_to_dma_buffer(sector : UInt64, nsectors : Int = 1)
      abort "can't access atapi" if @type == Type::Atapi
      abort "device doesn't support dma" if !@can_dma
      # Serial.print "ata read ", sector, '\n'

      retval = false
      Ide.lock do
        retries = 0
        while retries < MAX_RETRIES
          Ata.interrupted = false
          Ata.read_dma sector, disk_port, cmd_port, slave, nsectors.to_u8
          # poll
          while !Ata.interrupted
            asm("pause")
          end
          Ata.flush_dma
          retval = true
          break
        end
      end
      retval
    end

    MAX_RETRIES = 3

    def read_sector(ptr : UInt8*, sector : UInt64, nsectors : Int = 1)
      abort "can't access atapi" if @type == Type::Atapi
      # Serial.print "ata read ", sector, '\n'

      retval = false
      Ide.lock do
        retries = 0
        while retries < MAX_RETRIES
          if @can_dma
            Ata.interrupted = false
            Ata.read_dma sector, disk_port, cmd_port, slave, nsectors.to_u8
            # poll
            while !Ata.interrupted
              asm("pause")
            end
            memcpy(ptr, Ide.dma_buffer, 512u64 * nsectors)
            Ata.flush_dma
          else
            Ata.read sector, disk_port, slave, nsectors.to_u8
            # poll
            unless Ata.wait(disk_port, true)
              retval = false
              retries += 1
              next
            end
            # read from sector
            l0 = l1 = 0
            nwords = 256 * nsectors
            asm("rep insw"
                    : "={Di}"(l0), "={cx}"(l1)
                    : "{Di}"(ptr), "{cx}"(nwords), "{dx}"(disk_port)
                    : "volatile", "memory")
          end
          retval = true
          break
        end
      end

      retval
    end
  end
end


module Ide
  extend self

  lib Data
    @[Packed]
    struct PhysicalRegionDescriptor
      address : UInt32
      size : UInt16
      end_of_table : UInt16
    end
  end

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

  @@bus_master = 0u16
  class_getter bus_master
  class_getter! devices

  @@prdt = uninitialized Data::PhysicalRegionDescriptor

  def prdt_ptr
    pointerof(@@prdt)
  end

  def prdt_ptr_phys
    Paging.virt_to_phys_address(prdt_ptr.as(Void*))
  end

  @@dma_buffer = Pointer(UInt8).null
  class_getter dma_buffer

  private def dma_buffer_phys
    @@dma_buffer.address & ~Paging::IDENTITY_MASK
  end

  @@bus = 0u32
  @@device = 0u32
  @@func = 0u32

  def init_controller(@@bus : UInt32, @@device : UInt32, @@func : UInt32)
    # set up dma transfers
    PCI.enable_bus_mastering @@bus, @@device, @@func
    @@bus_master = (PCI.read_long(@@bus, @@device, @@func, PCI::PCI_BAR4) & 0xFFFC).to_u16

    @@dma_buffer = Pointer(UInt8).new(FrameAllocator.claim_with_addr | Paging::IDENTITY_MASK)
    zero_page @@dma_buffer
    @@prdt.address = dma_buffer_phys
    @@prdt.end_of_table = 0x8000

    @@devices = Array(Ata::Device?).new 4

    devices.push Ata::Device.new(true, false)
    devices.push Ata::Device.new(true, true)
    devices.push Ata::Device.new(false, false)
    devices.push Ata::Device.new(false, true)

    Idt.register_irq 14, ->ata_primary_irq_handler
    Idt.register_irq 15, ->ata_secondary_irq_handler
    devices.size.times do |idx|
      unless devices[idx].not_nil!.init_device
        devices[idx] = nil
      end
    end
  end

  # interrupts
  def ata_primary_irq_handler
    Ata.irq_handler Ata::DISK_PORT_PRIMARY
  end

  def ata_secondary_irq_handler
    Ata.irq_handler Ata::DISK_PORT_SECONDARY
  end

  # check pci device
  def pci_device?(vendor_id, device_id)
    (vendor_id == 0x8086) && (device_id == 0x7010 || device_id == 0x7111)
  end

  # lock
  # FIXME: have separate locks for each ATA device
  @@lock = Spinlock.new

  def locked?
    @@lock.locked?
  end

  def lock(&block)
    @@lock.with do
      yield
    end
  end
end
