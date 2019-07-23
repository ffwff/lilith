private lib Kernel

    @[Packed]
    struct Gdtr
        size    : UInt16
        offset  : UInt32
    end

    @[Packed]
    struct GdtEntry
        limit_low   : UInt16
        base_low    : UInt16
        base_middle : UInt8
        access      : UInt8
        granularity : UInt8
        base_high   : UInt8
    end

    @[Packed]
    struct Tss
        prev_tss : UInt32
        esp0     : UInt32 # The stack pointer to load when we change to kernel mode.
        ss0      : UInt32 # The stack segment to load when we change to kernel mode.
        # Unused:
        esp1   : UInt32
        ss1    : UInt32
        esp2   : UInt32
        ss2    : UInt32
        cr3    : UInt32
        eip    : UInt32
        eflags : UInt32
        eax    : UInt32
        ecx    : UInt32
        edx    : UInt32
        ebx    : UInt32
        esp    : UInt32
        ebp    : UInt32
        esi    : UInt32
        edi    : UInt32
        es     : UInt32
        cs     : UInt32
        ss     : UInt32
        ds     : UInt32
        fs     : UInt32
        gs     : UInt32
        ldt    : UInt32
        trap       : UInt16
        iomap_base : UInt16
    end

    fun kload_gdt(ptr : UInt32)
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
        @@gdtr.offset = @@gdt.to_unsafe.address.to_u32
        
        init_gdt_entry 0, 0x0, 0x0, 0x0, 0x0          # null
        init_gdt_entry 1, 0x0, 0xFFFFFFFF, 0x9A, 0xCF # kernel code
        init_gdt_entry 2, 0x0, 0xFFFFFFFF, 0x92, 0xCF # kernel data
        init_gdt_entry 3, 0x0, 0xFFFFFFFF, 0xFA, 0xCF # user code
        init_gdt_entry 4, 0x0, 0xFFFFFFFF, 0xF2, 0xCF # user data
        init_tss 5, 0x10, 0x0


        Kernel.kload_gdt pointerof(@@gdtr).address.to_u32
        Kernel.kload_tss
    end

    private def init_gdt_entry(num : Int32,
            base : UInt32, limit : UInt32, access : UInt32, gran : UInt32)
        entry = Kernel::GdtEntry.new

        entry.base_low = (base & 0xFFFF).to_u16
        entry.base_middle = (base.unsafe_shr(16) & 0xFF).to_u8
        entry.base_high = (base.unsafe_shr(24) & 0xFF).to_u8
        entry.limit_low = (limit & 0xFFFF).to_u16
        entry.granularity = (limit.unsafe_shr(16) & 0x0F).to_u8

        entry.granularity |= gran & 0xF0
        entry.access = access.to_u8

        @@gdt[num] = entry
    end

    private def init_tss(num : Int32, ss0 : UInt32, esp0 : UInt32)
        base = pointerof(@@tss).address.to_u32
        limit = base + sizeof(Kernel::Tss)
        init_gdt_entry num, base, limit, 0xE9, 0x00
        @@tss.ss0 = ss0
        @@tss.esp0 = esp0
        @@tss.cs = 0x0b
        @@tss.ss = @@tss.ds = @@tss.es = @@tss.fs = @@tss.gs = 0x13
    end

    def stack; @@tss.esp0; end
    def stack=(stack : UInt32); @@tss.esp0 = stack; end

end
