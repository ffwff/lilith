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
        while i < aligned(text_end.address.to_u32)
            alloc_frame false, false, i
            i += 0x1000
        end
        # data segment
        i = data_start.address.to_u32
        while i < aligned(data_end.address.to_u32)
            alloc_frame true, false, i
            i += 0x1000
        end
        # unallocated stack protection pages
        while i < stack_start.address.to_u32
            @@frames[frame_index_for_address i] = true
            i += 0x1000
        end
        # stack segment
        i = stack_start.address.to_u32
        while i < aligned(stack_end.address.to_u32)
            alloc_frame true, false, i
            i += 0x1000
        end
        # heap
        i = Kernel.pmalloc_start.address.to_u32
        while i < aligned(Kernel.pmalloc_addr.address.to_u32)
            alloc_frame true, false, i
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
    def alloc_page(rw : Bool, user : Bool, address : UInt32)
        Kernel.kalloc_page (rw ? 1 : 0), (user ? 1 : 0), address
    end

    # frame alloc
    def alloc_frame(rw : Bool, user : Bool, address : UInt32)
        idx = frame_index_for_address address
        panic "already allocated" if @@frames[idx]
        @@frames[idx] = true
        alloc_page(rw, user, address)
    end

    private def frame_index_for_address(address : Int)
        (address - @@frame_base_addr).unsafe_div(0x1000)
    end

end