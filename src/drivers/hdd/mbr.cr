MBR_BOOTABLE_PARTITION = 0x80

module MBR
  extend self

  lib Data
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

  def read(device)
    mbr = Box(Data::MBR).new
    device.read_sector(mbr.to_unsafe.as(UInt8*), 0)
    return nil unless mbr.to_unsafe.value.header[0] == 0x55 &&
                      mbr.to_unsafe.value.header[1] == 0xaa
    mbr
  end
end
