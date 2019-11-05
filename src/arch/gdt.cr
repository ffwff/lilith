GDT_REGULARS = 7

private lib Kernel
  @[Packed]
  struct Gdtr
    size : UInt16
    offset : UInt64
  end

  @[Packed]
  struct GdtEntry
    limit_low : UInt16
    base_low : UInt16
    base_middle : UInt8
    access : UInt8
    granularity : UInt8
    base_high : UInt8
  end

  @[Packed]
  struct GdtSystemEntry
    limit_low : UInt16
    base_low : UInt16
    base_middle : UInt8
    access : UInt8
    granularity : UInt8
    base_high : UInt8
    base_higher : UInt32
    reserved : UInt32
  end

  @[Packed]
  struct Tss
    reserved : UInt32
    rsp0 : UInt64
    rsp1 : UInt64
    rsp2 : UInt64
    reserved_1 : UInt64
    ist_1 : UInt64
    ist_2 : UInt64
    ist_3 : UInt64
    ist_4 : UInt64
    ist_5 : UInt64
    ist_6 : UInt64
    ist_7 : UInt64
    reserved_2 : UInt64
    reserved_3 : UInt32
    iopb : UInt32
  end

  @[Packed]
  struct Gdt
    entries : Kernel::GdtEntry[GDT_REGULARS]
    sys_entries : GdtSystemEntry[1] # tss
  end

  fun kload_gdt(ptr : Gdtr*)
end

module Gdt
  extend self

  @@gdtr = uninitialized Kernel::Gdtr
  @@gdt = uninitialized Kernel::Gdt
  @@tss = uninitialized Kernel::Tss

  def init_table
    @@gdtr.size = sizeof(Kernel::Gdt) - 1
    @@gdtr.offset = pointerof(@@gdt).address

    # this must be placed in the following order
    # so that sysenter sets the selectors correctly
    init_gdt_entry 0, 0x0, 0x0, 0x0, 0x0          # null
    init_gdt_entry 1, 0x0, 0xFFFFFFFF, 0x9A, 0xAF # kernel code (64-bit)
    init_gdt_entry 2, 0x0, 0xFFFFFFFF, 0x92, 0x0F # kernel data (64-bit)
    init_gdt_entry 3, 0x0, 0xFFFFFFFF, 0x00, 0x00 # user code
    init_gdt_entry 4, 0x0, 0xFFFFFFFF, 0x00, 0x00 # user data
    init_gdt_entry 5, 0x0, 0xFFFFFFFF, 0xBA, 0xAF # device code (CPL=1)
    init_gdt_entry 6, 0x0, 0xFFFFFFFF, 0xB2, 0xAF # device data (CPL=1)
    init_tss

    Kernel.kload_gdt pointerof(@@gdtr)
  end

  def switch_user_32
    init_gdt_entry 3, 0x0, 0xFFFFFFFF, 0xFA, 0xCF # user code (32-bit)
    init_gdt_entry 4, 0x0, 0xFFFFFFFF, 0xF2, 0xCF # user data (32-bit)
    asm("lgdt ($0)" :: "r"(pointerof(@@gdtr)) : "volatile", "memory")
  end

  def switch_user_64
    init_gdt_entry 3, 0x0, 0xFFFFFFFF, 0xFA, 0xFF # user code (64-bit)
    init_gdt_entry 4, 0x0, 0xFFFFFFFF, 0xF2, 0xFF # user data (64-bit)
    asm("lgdt ($0)" :: "r"(pointerof(@@gdtr)) : "volatile", "memory")
  end

  private def init_gdt_entry(num : ISize,
                             base : USize, limit : USize, access : USize, gran : USize)
    entry = Kernel::GdtEntry.new

    entry.base_low = (base & 0xFFFF).to_u16
    entry.base_middle = ((base >> 16) & 0xFF).to_u8
    entry.base_high = ((base >> 24) & 0xFF).to_u8

    entry.limit_low = (limit & 0xFFFF).to_u16
    entry.granularity = ((limit >> 16) & 0x0F).to_u8

    entry.granularity |= gran
    entry.access = access.to_u8

    @@gdt.entries[num] = entry
  end

  private def init_gdt_sys_entry(num : ISize,
                                 base : USize, limit : USize, access : USize, gran : USize)
    entry = Kernel::GdtSystemEntry.new

    entry.base_low = (base & 0xFFFF).to_u16
    entry.base_middle = ((base >> 16) & 0xFF).to_u8
    entry.base_high = ((base >> 24) & 0xFF).to_u8
    entry.base_higher = (base >> 32).to_u32

    entry.limit_low = (limit & 0xFFFF).to_u16
    entry.granularity = ((limit >> 16) & 0x0F).to_u8

    entry.granularity |= gran
    entry.access = access.to_u8
    entry.reserved = 0

    @@gdt.sys_entries[num] = entry
  end

  private def init_tss
    @@tss.iopb = sizeof(Kernel::Tss)
    base = pointerof(@@tss).address
    limit = sizeof(Kernel::Tss).to_usize - 1
    init_gdt_sys_entry 0, base, limit, 0x89, 0x0
  end

  def flush_tss
    asm("mov $$0x3A, %bx
         ltr %bx" ::: "volatile", "bx")
  end

  def stack : Void*
    Pointer(Void).new(@@tss.rsp0)
  end

  def stack=(stack : Void*)
    @@tss.rsp0 = stack.address
  end
end
