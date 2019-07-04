private lib Kernel
    fun kinit_paging()
    fun kenable_paging()
    fun kdisable_paging()
    fun kalloc_page(rw : Int32, user : Int32, address : UInt32)
    $kernel_page_dir : Void*
    $pmalloc_start : Void*
    $pmalloc_addr : Void*
end

module Paging
    extend self

    def init_table(
        text_start : Void*, text_end : Void*,
        data_start : Void*, data_end : Void*,
        stack_end : Void*, stack_start : Void*
    )
        Kernel.kinit_paging()
        alloc_page 0, 0, 0xb8000
        # text segment
        i = text_start.address.to_u32
        while i <= aligned(text_end.address.to_u32)
            alloc_page 0, 0, i
            i += 0x1000
        end
        # data segment
        i = data_start.address.to_u32
        while i <= aligned(data_end.address.to_u32)
            alloc_page 1, 0, i
            i += 0x1000
        end
        # stack segment
        i = stack_start.address.to_u32
        while i <= aligned(stack_end.address.to_u32)
            alloc_page 1, 0, i
            i += 0x1000
        end
        # heap
        i = Kernel.pmalloc_start.address.to_u32
        while i <= Kernel.pmalloc_addr.address.to_u32
            alloc_page 1, 0, i
            i += 0x1000
        end
        # -- switch page directory
        enable
    end

    private def aligned(x : UInt32) : UInt32
        (x & 0xFFFFF000) + 0x1000
    end

    # state
    @[AlwaysInline]
    def enable
        Kernel.kenable_paging
    end

    @[AlwaysInline]
    def disable
        Kernel.kdisable_paging
    end

    # page alloc
    @[AlwaysInline]
    def alloc_page(rw : Int32, user : Int32, address : UInt32)
        Kernel.kalloc_page rw, user, address
    end

end