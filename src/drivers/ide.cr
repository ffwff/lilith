private lib Kernel

    # T13/1699-D Revision 3f
    # 7.16 IDENTIFY DEVICE, pg 90
    # also see ftp://ftp.seagate.com/acrobat/reference/111-1c.pdf
    @[Packed]
    struct AtaIdentify
        flags            : UInt16
        unused1          : UInt16[9]
        serial           : UInt8[20]
        unused2          : UInt16[3]
        firmware         : UInt8[8]
        model            : UInt8[40]
        # Maximum number of logical sectors that shall be transferred per DRQ data block on READ/WRITE MULTIPLE commands
        sectors_per_int  : UInt16
        unused3          : UInt16
        capabilities     : UInt16[2]
        unused4          : UInt16[2]
        valid_ext_data   : UInt16
        unused5          : UInt16[5]
        size_of_rw_mult  : UInt16
        # Total number of user addressable logical sectors
        sectors_28       : UInt32
        unused6          : UInt16[38]
        # Total Number of User Addressable Sectors for the 48-bit Address feature set
        sectors_48       : UInt64
        unused7          : UInt16[152]
    end

end

private module Ata
    extend self

    # statuses
    SR_BSY =     0x80
    SR_DRDY =    0x40
    SR_DF =      0x20
    SR_DSC =     0x10
    SR_DRQ =     0x08
    SR_CORR =    0x04
    SR_IDX =     0x02
    SR_ERR =     0x01

    # error codes
    ER_BBK =      0x80
    ER_UNC =      0x40
    ER_MC =       0x20
    ER_IDNF =     0x10
    ER_MCR =      0x08
    ER_ABRT =     0x04
    ER_TK0NF =    0x02
    ER_AMNF =     0x01

    # ide commands
    CMD_READ_PIO =          0x20u8
    CMD_READ_PIO_EXT =      0x24u8
    CMD_READ_DMA =          0xC8u8
    CMD_READ_DMA_EXT =      0x25u8
    CMD_WRITE_PIO =         0x30u8
    CMD_WRITE_PIO_EXT =     0x34u8
    CMD_WRITE_DMA =         0xCAu8
    CMD_WRITE_DMA_EXT =     0x35u8
    CMD_CACHE_FLUSH =       0xE7u8
    CMD_CACHE_FLUSH_EXT =   0xEAu8
    CMD_PACKET =            0xA0u8
    CMD_IDENTIFY_PACKET =   0xA1u8
    CMD_IDENTIFY =          0xECu8

    # identifiers
    IDENT_DEVICETYPE =   0
    IDENT_CYLINDERS =    2
    IDENT_HEADS =        6
    IDENT_SECTORS =      12
    IDENT_SERIAL =       20
    IDENT_MODEL =        54
    IDENT_CAPABILITIES = 98
    IDENT_FIELDVALID =   106
    IDENT_MAX_LBA =      120
    IDENT_COMMANDSETS =  164
    IDENT_MAX_LBA_EXT =  200

    #
    MASTER =     0x00
    SLAVE =      0x01

    #
    REG_DATA =       0x00u16
    REG_ERROR =      0x01u16
    REG_FEATURES =   0x01u16
    REG_SECCOUNT0 =  0x02u16
    REG_LBA0 =       0x03u16
    REG_LBA1 =       0x04u16
    REG_LBA2 =       0x05u16
    REG_HDDEVSEL =   0x06u16
    REG_COMMAND =    0x07u16
    REG_STATUS =     0x07u16
    REG_SECCOUNT1 =  0x08u16
    REG_LBA3 =       0x09u16
    REG_LBA4 =       0x0Au16
    REG_LBA5 =       0x0Bu16
    REG_CONTROL =    0x0Cu16
    REG_ALTSTATUS =  0x0Cu16
    REG_DEVADDRESS = 0x0Du16

    # channels
    CHAN_PRIMARY =      0x00
    CHAN_SECONDARY =    0x01

    # directions
    DIR_READ =      0x00
    DIR_WRITE =     0x01

    # drive = 0 => primary
    # drive = 1 => secondary
    def select(bus, slave=0u8)
        X86.outb(bus + REG_HDDEVSEL, 0xA0.to_u8 | slave.unsafe_shl(4))
    end

    def identify(bus)
        X86.outb(bus + REG_COMMAND, CMD_IDENTIFY)
    end

    def status(bus)
        X86.inb(bus + REG_COMMAND)
    end

    # wait functions
    def wait_io(bus)
        4.times {|i| X86.inb(bus + REG_ALTSTATUS) }
    end
    def wait_ready(bus)
        while ((status = X86.inb(bus + REG_STATUS)) & SR_BSY) != 0
        end
        status
    end
    def wait(bus, advanced=false)
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
    def read_cmd(sector_28, bus, slave)
        wait_ready bus

        X86.outb(bus + REG_HDDEVSEL,  (0xe0 | slave.unsafe_shl(4) |
                            (sector_28 & 0x0f000000).unsafe_shr(24)).to_u8)
        X86.outb(bus + REG_FEATURES, 0x00)
        X86.outb(bus + REG_SECCOUNT0, 1)
        X86.outb(bus + REG_LBA0, (sector_28 & 0x000000ff).to_u8)
        X86.outb(bus + REG_LBA1, (sector_28 & 0x0000ff00).unsafe_shr(8).to_u8)
        X86.outb(bus + REG_LBA2, (sector_28 & 0x00ff0000).unsafe_shr(16).to_u8)
        X86.outb(bus + REG_COMMAND, CMD_READ_PIO)
    end

    def flush_cache(bus)
        X86.outb(bus + REG_COMMAND, CMD_CACHE_FLUSH)
    end

    # irq handler
    def irq_handler(bus)
        X86.inb(bus + REG_STATUS)
    end

end

private DISK_PORT_PRIMARY = 0x1F0u16
private CMD_PORT_PRIMARY = 0x3F6u16
private DISK_PORT_SECONDARY = 0x170u16
private CMD_PORT_SECONDARY = 0x3F4u16

class AtaDevice < Gc

    def disk_port
        @primary ? DISK_PORT_PRIMARY : DISK_PORT_SECONDARY
    end
    def cmd_port
        @primary ? CMD_PORT_PRIMARY : CMD_PORT_SECONDARY
    end

    #
    getter primary, slave
    @identification : Kernel::AtaIdentify | Nil = nil
    getter identification

    # NOTE: idx must be between 0..3
    def initialize(@idx = 0, @primary=true, @slave=0)
    end

    # NOTE: for some reason i can't store pointers inside AtaDevice
    def name
        name = CString.new("ata0", 4)
        name.not_nil![3] = (@idx + '0'.ord).to_u8
        name
    end

    #
    def init_device
        X86.outb disk_port + 1, 1
        X86.outb disk_port + 0x306, 0

        Ata.select disk_port, @slave
        Ata.wait_io disk_port

        Ata.identify disk_port
        Ata.wait_io disk_port

        status = Ata.status disk_port
        debug "status: ", status, '\n'
        return if status == 0

        X86.outb cmd_port, 0x02

        # read device identifier
        device = uninitialized Kernel::AtaIdentify
        begin
            buf = Pointer(UInt16).new(pointerof(device).address)
            256.times do |i|
                buf[i] = X86.inw disk_port
            end
        end

        # fix model name from endianness
        begin
            {% for key in ["serial", "firmware", "model"] %}
            {% key = key.id %}
            i = 0
            while i < device.{{ key }}.size
                device.{{ key }}[i], device.{{ key }}[i+1] = device.{{ key }}[i+1], device.{{ key }}[i]
                i += 2
            end
            {% end %}
        end

        @identification = device
    end

    def read_sector(sector_28, &block)
        Ata.read_cmd sector_28, disk_port, slave
        return false if !Ata.wait(disk_port, true)
        256.times do |i|
            yield X86.inw disk_port
        end
        Ata.flush_cache disk_port
        Ata.wait disk_port
        true
    end

    def read_sector_pointer(ptr : UInt16*, sector_28)
        idx = 0
        read_sector(sector_28) do |i|
            ptr[idx] = i
            idx += 1
        end
    end

    #
    def debug(*args)
        VGA.puts *args
    end

end

class Ide < Gc

    def device(idx)
        @devices.not_nil![idx].not_nil!
    end

    def init_controller
        Serial.puts offsetof(Kernel::AtaIdentify, @sectors_per_int), '\n'
        debug "Initializing IDE device...\n"

        @devices = GcArray(AtaDevice).new 4
        devices = @devices.not_nil!
        devices[0] = AtaDevice.new(0, true, 0)
        devices[1] = AtaDevice.new(1, true, 1)
        devices[2] = AtaDevice.new(2, false, 0)
        devices[3] = AtaDevice.new(3, false, 1)

        Idt.register_irq 14, ->ata_primary_irq_handler
        Idt.register_irq 15, ->ata_secondary_irq_handler
        4.times do |idx|
            devices[idx].not_nil!.init_device
        end
    end

    #
    def debug(*args)
        VGA.puts *args
    end

    # interrupts
    def ata_primary_irq_handler
        Ata.irq_handler DISK_PORT_PRIMARY
    end
    def ata_secondary_irq_handler
        Ata.irq_handler DISK_PORT_SECONDARY
    end

end