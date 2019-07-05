# NOTE: we only do identity paging

private lib Kernel
    fun kinit_paging()
    fun kenable_paging()
    fun kdisable_paging()
    fun kalloc_page(rw : Int32, user : Int32, address : UInt32)
    fun kalloc_page_no_make(rw : Int32, user : Int32, address : UInt32)
    fun kpage_present(address : UInt32) : Int32
    fun kpage_dir_set_table(idx : UInt32, address : UInt32)
    fun kpage_table_present(address : UInt32) : Int32
    $kernel_page_dir : Void*
    $pmalloc_start : Void*
    $pmalloc_addr : Void*
end

module Paging
    extend self

    @@frame_base_addr : UInt32 = 0
    @@frame_length    : UInt32 = 0
    @@frames = PBitArray.null

    def init_table(
        text_start : Void*, text_end : Void*,
        data_start : Void*, data_end : Void*,
        stack_end : Void*, stack_start : Void*,
        mboot_header : Multiboot::MultibootInfo*
    )
        Kernel.kinit_paging

        cur_mmap_addr = mboot_header[0].mmap_addr
        mmap_end_addr = cur_mmap_addr + mboot_header[0].mmap_length

        while cur_mmap_addr < mmap_end_addr
            cur_entry = Pointer(Multiboot::MemoryMapTable).new(cur_mmap_addr.to_u64)

            if cur_entry[0].base_addr != 0 && cur_entry[0].type == MULTIBOOT_MEMORY_AVAILABLE
                entry = cur_entry[0]
                @@frame_base_addr = entry.base_addr.to_u32
                @@frame_length = entry.length.to_u32
                break
            end

            cur_mmap_addr += cur_entry[0].size + sizeof(UInt32)
        end

        panic "can't find page frames" if @@frame_length == 0
        nframes = @@frame_length.to_i32.unsafe_div 0x1000
        @@frames = PBitArray.new nframes

        # vga
        alloc_page false, false, 0xb8000

        # text segment
        i = text_start.address.to_u32
        while i < text_end.address.to_u32
            alloc_frame false, false, i
            i += 0x1000
        end
        # data segment
        i = data_start.address.to_u32
        while i < data_end.address.to_u32
            alloc_frame true, false, i
            i += 0x1000
        end
        # stack segment
        i = stack_start.address.to_u32
        while i < stack_end.address.to_u32
            alloc_frame true, false, i
            i += 0x1000
        end
        # heap
        i = Kernel.pmalloc_start.address.to_u32
        while i <= aligned(Kernel.pmalloc_addr.address.to_u32)
            alloc_frame false, false, i
            i += 0x1000
        end
        # -- switch page directory
        enable
    end

    def aligned(x : UInt32) : UInt32
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
    private def alloc_page(rw : Bool, user : Bool, address : UInt32)
        Kernel.kalloc_page (rw ? 1 : 0), (user ? 1 : 0), address
    end

    # allocate page when pg is enabled
    # returns page address
    def alloc_page_pg : UInt32
        # reuse page if table is already allocated
        iaddr = @@frames.first_unset
        addr = iaddr.to_u32 * 0x1000 + @@frame_base_addr
        if Kernel.kpage_present(addr) != 0
            return addr
        end

        Idt.disable
        disable
        # claim
        @@frames[iaddr] = true
        # create new page
        page_addr = addr.unsafe_div 0x1000
        table_idx = page_addr.unsafe_div 1024
        if Kernel.kpage_table_present(table_idx) == 0
            # page table isn't present
            # claim a page for storing the page table
            pt_iaddr = @@frames.first_unset
            pt_addr = pt_iaddr.to_u32 * 0x1000 + @@frame_base_addr
            memset Pointer(UInt8).new(pt_addr.to_u64), 0, 4096
            Kernel.kpage_dir_set_table table_idx, pt_addr
            alloc_frame(false, false, pt_addr)
        end
        Kernel.kalloc_page_no_make 1, 0, addr
        enable
        Idt.enable

        # return page
        addr
    end

    def free_page_pg(address : UInt32)
        @@frames[frame_index_for_address address] = false
    end

    # frame alloc
    def alloc_frame(rw : Bool, user : Bool, address : UInt32)
        idx = frame_index_for_address address
        panic "already allocated" if @@frames[idx]
        @@frames[idx] = true
        alloc_page(rw, user, address)
    end

    private def frame_index_for_address(address : UInt32)
        (address - @@frame_base_addr).unsafe_div(0x1000)
    end

end