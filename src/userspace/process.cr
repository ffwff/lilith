private lib Kernel
    fun kset_stack(address : UInt32)
    fun kswitch_usermode()
end


module Multiprocessing
    extend self

    USER_STACK_TOP = 0xf000_0000u32

    @@current_process : Process | Nil = nil
    mod_property current_process
    @@first_process : Process | Nil = nil
    mod_property first_process
    @@pids = 0u32
    mod_property pids

    class Process < Gc

        @pid = 0u32
        getter pid
        @next_process : Process | Nil = nil
        getter next_process

        @stack_bottom : UInt32 = USER_STACK_TOP - 0x1000u32

        # physical location of the process' page directory
        @phys_page_dir : UInt32 = 0
        getter phys_page_dir

        def initialize(vfs : VFSNode, fs : VFS)
            # TODO support something other than flat binaries
            code_pages = vfs.size.div_ceil 0x1000
            panic "no pages" if code_pages < 1

            Idt.disable

            @pid = Multiprocessing.pids
            last_page_dir = Pointer(PageStructs::PageDirectory).null
            if @pid != 0
                Paging.disable
                last_page_dir = Paging.current_page_dir
                page_dir = Paging.alloc_process_page_dir
                Paging.current_page_dir = Pointer(PageStructs::PageDirectory).new page_dir
                Paging.enable
                @phys_page_dir = page_dir.to_u32
            else
                @phys_page_dir = Paging.current_page_dir.address.to_u32
            end
            Multiprocessing.pids += 1

            # data pages
            page = Paging.alloc_page_pg 0x8000_0000, true, true, code_pages
            ptr = Pointer(UInt8).new(page.to_u64)
            i = 0
            vfs.read(fs) do |ch|
                ptr[i] = ch
                i += 1
            end

            # stack
            stack_top = Paging.alloc_page_pg @stack_bottom, true, true, 1

            if Multiprocessing.first_process.nil?
                Multiprocessing.first_process = self
            else
                @next_process = Multiprocessing.first_process
                Multiprocessing.first_process = self
            end

            Idt.enable

            if !last_page_dir.null?
                Paging.disable
                Paging.current_page_dir = last_page_dir
                Paging.enable
            end
        end

        def switch
            Multiprocessing.current_process = self
            Idt.disable
            Serial.puts "obj: ", self.object_id, "\n"
            dir = @phys_page_dir # this must be stack allocated
            # because it's placed in the virtual kernel heap
            panic "page dir is nil" if dir == 0
            Paging.disable
            Paging.current_page_dir = Pointer(PageStructs::PageDirectory).new(dir.to_u64)
            Paging.enable
            esp0 = 0u32
            asm("mov %esp, $0;" : "=r"(esp0) :: "volatile")
            Kernel.kset_stack esp0
            Kernel.kswitch_usermode
        end

    end

end