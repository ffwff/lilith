lib MBRStructs
  @[Packed]
  struct PartitionTable
    status : UInt8
    chs_first_sector : UInt8[3]
    type : UInt8
    chs_last_sector : UInt8[3]
    first_sector : UInt32
    n_sectors : UInt32
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

  def read(device)
    mbr = Box(MBRStructs::MBR).new
    device.read_sector(mbr.to_unsafe.as(UInt16*), 0)
    return nil unless mbr.to_unsafe.value.header[0] == 0x55 &&
                      mbr.to_unsafe.value.header[1] == 0xaa
    mbr
  end

end
