lib Multiboot
  struct ElfSectionHeaderTable
    num : UInt32
    size : UInt32
    addr : UInt32
    shndx : UInt32
  end

  struct MultibootInfo
    flags : UInt32
    mem_lower : UInt32
    mem_upper : UInt32
    boot_device : UInt32
    cmdline : UInt32
    mods_count : UInt32
    mods_addr : UInt32
    elf_sec : ElfSectionHeaderTable
    mmap_length : UInt32
    mmap_addr : UInt32
  end

  @[Packed]
  struct MemoryMapTable
    size : UInt32
    base_addr : UInt64
    length : UInt64
    type : UInt32
  end
end

MULTIBOOT_BOOTLOADER_MAGIC = 0x2BADB002
MULTIBOOT_MEMORY_AVAILABLE =          1
MULTIBOOT_MEMORY_RESERVED  =          2
