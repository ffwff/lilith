lib MBRStructs

    @[Packed]
    struct PartitionTable
        status           : UInt8
        chs_first_sector : UInt8[3]
        type             : UInt8
        chs_last_sector  : UInt8[3]
        start_sector     : UInt32
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

    def read_ide
        mbr = uninitialized MBRStructs::MBR
        pointer = Pointer(UInt16).new(pointerof(mbr).address)
        idx = 0
        Ide.read_sector(0) do |word|
            pointer[idx] = word
            idx += 1
        end
        mbr
    end

end