private lib Kernel

    @[Packed]
    struct AtaIdentify
        flags            : UInt16
        unused1          : UInt16[9]
        serial           : UInt8[20]
        unused2          : UInt16[3]
        firmware         : UInt8[8]
        model            : UInt8[40]
        sectors_per_int  : UInt16
        unused3          : UInt16
        capabilities     : UInt16[2]
        unused4          : UInt16[2]
        valid_ext_data   : UInt16
        unused5          : UInt16[5]
        size_of_rw_mult  : UInt16
        sectors_28       : UInt32
        unused6          : UInt16[38]
        sectors_48       : UInt64
        unused7          : UInt16[152]
    end

end

private struct Ata

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

    @bus = 0u16
    def bus; @bus; end
    def bus=(x); @bus = x; end

    def select
        X86.outb(bus + REG_HDDEVSEL, 0xA0)
    end

    def identify
        X86.outb(bus + REG_COMMAND, CMD_IDENTIFY)
    end

    def status
        X86.inb(bus + REG_COMMAND)
    end

    # wait functions
    def wait_io
        4.times {|i| X86.inb(bus + REG_ALTSTATUS) }
    end
    def wait_ready
        while (status = X86.inb(bus + REG_STATUS) & SR_BUSY) != 0
        end
        status
    end
    def wait(advanced=false)
        wait_io
        status = wait_ready
        if advanced
            status = X86.inb(bus + ATA_REG_STATUS);
            if (status & SR_ERR) != 0 ||
               (status & SR_DF)  != 0 ||
               (status & SR_DRQ) == 0
               return 1
            end
        end
        0
    end

end

module Ide
    extend self

    DISK_PORT = 0x1F0u16

    @@ata = Ata.new

    def init_controller
        debug "Initializing IDE device...\n"

        @@ata.bus = DISK_PORT

        X86.outb @@ata.bus + 1, 1
        X86.outb @@ata.bus + 0x306, 0

        @@ata.select
        @@ata.wait_io

        @@ata.identify
        @@ata.wait_io

        status = @@ata.status
        debug "status: ", status, '\n'
        return if status == 0

        # read device identifier
        device = uninitialized Kernel::AtaIdentify
        begin
            buf = Pointer(UInt16).new(pointerof(device).address)
            256.times do |i|
                buf[i] = X86.inw @@ata.bus
            end
        end

        # fix model name from endianness
        begin
            i = 0
            while i < device.model.size
                device.model[i], device.model[i+1] = device.model[i+1], device.model[i]
                i += 2
            end
        end

        #output
        device.model.each do |i|
            debug i.unsafe_chr
        end
        debug "\n"
    end

    def debug(*args)
        VGA.puts *args
    end

end