lib MBRStructs

    @[Packed]
    struct PartitionTable
        status           : UInt8
        chs_first_sector : UInt8[3]
        type             : UInt8
        chs_last_sector  : UInt8[3]
        first_sector     : UInt32
        n_sectors        : UInt32
    end

    @[Packed]
    struct MBR
        bootstrap : UInt8[446]
        partitions : PartitionTable[4]
        header : UInt8[2]
    end

end

MBR_BOOTABLE_PARTITION = 0x80

module MBR
    extend self

    def read_ide(device)
        mbr = uninitialized MBRStructs::MBR
        device.read_sector_pointer(Pointer(UInt16).new(pointerof(mbr).address), 0)
        mbr
    end

end