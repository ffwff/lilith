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
    iopb : UInt32
  end

  fun kload_gdt(ptr : USize)
  fun kload_tss
end

module Gdt
  extend self

  GDT_SIZE = 6
  @@gdtr = uninitialized Kernel::Gdtr
  @@gdt = uninitialized Kernel::GdtEntry[GDT_SIZE]
  @@tss = uninitialized Kernel::Tss

  def init_table
    @@gdtr.size = sizeof(Kernel::GdtEntry) * GDT_SIZE - 1
    @@gdtr.offset = @@gdt.to_unsafe.address

    # this must be placed in the following order
    # so that sysenter sets the selectors correctly
    init_gdt_entry 0, 0x0, 0x0, 0x0, 0x0          # null
    init_gdt_entry 1, 0x0, 0xFFFFFFFF, 0x9A, 0xAF # kernel code (64-bit)
    init_gdt_entry 2, 0x0, 0xFFFFFFFF, 0x92, 0xAF # kernel data (64-bit)
    init_gdt_entry 3, 0x0, 0xFFFFFFFF, 0xFA, 0xCF # user code
    init_gdt_entry 4, 0x0, 0xFFFFFFFF, 0xF2, 0xCF # user data
    init_tss 5

    Kernel.kload_gdt pointerof(@@gdtr).address.to_u32
    Kernel.kload_tss
  end

  private def init_gdt_entry(num : ISize,
                             base : USize, limit : USize, access : USize, gran : USize)
    entry = Kernel::GdtEntry.new

    entry.base_low = (base & 0xFFFF).to_u16
    entry.base_middle = (base.unsafe_shr(16) & 0xFF).to_u8
    entry.base_high = (base.unsafe_shr(24) & 0xFF).to_u8
    entry.limit_low = (limit & 0xFFFF).to_u16
    entry.granularity = (limit.unsafe_shr(16) & 0x0F).to_u8

    entry.granularity |= gran
    entry.access = access.to_u8

    @@gdt[num] = entry
  end

  private def init_tss(num : ISize)
    base = pointerof(@@tss).address
    limit = base + sizeof(Kernel::Tss)
    init_gdt_entry num, base, limit, 0xE9, 0xAF
  end

  def stack
    @@tss.rsp0
  end

  def stack=(stack : USize)
    @@tss.rsp0 = stack
  end
end
