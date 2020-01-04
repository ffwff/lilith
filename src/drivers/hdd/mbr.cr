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

  @@mbr = uninitialized Data::MBR

  def read(device, &block)
    device.read_sector(pointerof(@@mbr).as(UInt8*), 0)
    return nil unless @@mbr.header[0] == 0x55 &&
                      @@mbr.header[1] == 0xaa
    yield @@mbr
  end
end
