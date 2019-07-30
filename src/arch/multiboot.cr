lib Multiboot
  @[Packed]
  struct MultibootInfo
    flags             : UInt32
    mem_lower         : UInt32
    mem_upper         : UInt32
    boot_device       : UInt32
    cmdline           : UInt32
    mods_count        : UInt32
    mods_addr         : UInt32
    elf_sec           : ElfSectionHeaderTable

    mmap_length       : UInt32
    mmap_addr         : UInt32

    drives_length     : UInt32
    drives_addr       : UInt32

    config_table      : UInt32

    boot_loader_name  : UInt32

    apm_table         : UInt32

    vbe_control_info  : UInt32
    vbe_mode_info     : UInt32
    vbe_mode          : UInt32
    vbe_interface_seg : UInt32
    vbe_interface_off : UInt32
    vbe_interface_len : UInt32

    framebuffer_addr   : UInt32
    framebuffer_pitch  : UInt32
    framebuffer_width  : UInt32
    framebuffer_height : UInt32
    framebuffer_bpp    : UInt8
  end

  struct ElfSectionHeaderTable
    num : UInt32
    size : UInt32
    addr : UInt32
    shndx : UInt32
  end

  @[Packed]
  struct MemoryMapTable
    size : UInt32
    base_addr : UInt64
    length : UInt64
    type : UInt32
  end

  @[Packed]
  struct VbeInfo
    attributes   : UInt16
    win_a, win_b : UInt8
    granularity  : UInt16
    winsize      : UInt16  
    segment_a    : UInt16
    segment_b    : UInt16
    real_fct_ptr : UInt32
    pitch        : UInt16

    x_res        : UInt16 
    y_res        : UInt16 
    w_char, y_char, planes, bpp, banks : UInt8
    memory_model, bank_size, image_pages : UInt8
    reserved0 : UInt8

    red_mask, red_position     : UInt8
    green_mask, green_position : UInt8
    blue_mask, blue_position   : UInt8
    rsv_mask, rsv_position     : UInt8
    directcolor_attributes     : UInt8

    physbase  : UInt32
    reserved1 : UInt32
    reserved2 : UInt16
  end
end

MULTIBOOT_BOOTLOADER_MAGIC = 0x2BADB002
MULTIBOOT_MEMORY_AVAILABLE =          1
MULTIBOOT_MEMORY_RESERVED  =          2

MULTIBOOT_FRAMEBUFFER_TYPE_INDEXED  = 0
MULTIBOOT_FRAMEBUFFER_TYPE_RGB      = 1
MULTIBOOT_FRAMEBUFFER_TYPE_EGA_TEXT = 2
