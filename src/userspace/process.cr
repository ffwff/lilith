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

    class Process < Gc

        @next : Process | Nil = nil
        @stack_bottom : UInt32 = USER_STACK_TOP - 0x1000

        def initialize(vfs : VFSNode, fs : VFS)
            # TODO support something other than flat binaries
            code_pages = vfs.size.div_ceil 0x1000
            panic "no pages" if !code_pages

            # data pages
            page = Paging.alloc_page_pg(0x8000_0000, true, true, code_pages)
            ptr = Pointer(UInt8).new(page.to_u64)
            i = 0
            vfs.read(fs) do |ch|
                ptr[i] = ch
                i += 1
            end

            # stack
            stack_top = Paging.alloc_page_pg(@stack_bottom, true, true, 4)

            if Multiprocessing.first_process.nil?
                Multiprocessing.first_process = self
            else
                panic "multiprocessing not supported"
            end
        end

        def switch
            Multiprocessing.current_process = self
            esp0 = 0u32
            asm("mov %esp, $0;" : "=r"(esp0) :: "volatile")
            Kernel.kset_stack esp0
            Kernel.kswitch_usermode
        end

    end

end