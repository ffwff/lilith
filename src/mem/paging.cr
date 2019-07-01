require "../core/pointer.cr"
require "../core/static_array.cr"

private lib Kernel
    $kernel_start : UInt32
    $kernel_end : UInt32
    fun kinit_paging(UInt32)
end

module X86
    extend self

    @[Packed]
    struct Page # 4kb
        @data : UInt32 = 0

        def initialize(ptr : UInt32)
            # NOTE: we use 4mb pages for identity mapping
            # . = bits unused by processor
            # # = reserved bits
            # * = pointer bits (shifted right 10 bits)
            #         PRUWDA0SG...##########
            @data = 0b1101000100000000000000 |
                      ptr.unsafe_shr(10)
        end

        def self.null
            Page { 0 }
        end
    end

    @[Packed]
    struct PageTable # 4mb
        @pages = uninitialized Page[1024]
        def new : Pointer(PageTable)
            table = pmalloc_a
            table.pages.size.each do |i|
                table.pages[i] = Page.null
            end
            table
        end
    end

    @[Packed]
    struct PageDirectory
        @tables = uninitialized PageTable*[1024]
        def tables
            @tables
        end
    end

    # current page dir
    def init_paging
        dir = Pointer(PageDirectory).pmalloc_a
        memset dir.to_byte_ptr, 0.to_u8!, sizeof(PageDirectory).to_u32
        switch_page_directory dir
        asm("
            pushl %eax
            movl %cr0, %eax
            orl $$0x80000000, %eax
            movl %eax, %cr0
            popl %eax
        ")
    end

    @@current_directory = Pointer(PageDirectory).null
    private def switch_page_directory(directory : PageDirectory*)
        @@current_directory = directory
        asm("movl $0, %cr3" :: "{eax}"(directory.value.tables.to_unsafe))
    end


end