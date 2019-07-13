require "./file_descriptor.cr"

private lib Kernel
    fun kset_stack(address : UInt32)
    fun kswitch_usermode()
end


module Multiprocessing
    extend self

    USER_STACK_TOP = 0xf000_0000u32
    USER_STACK_BOTTOM = 0x8000_0000u32

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
        property stack_bottom

        # physical location of the process' page directory
        @phys_page_dir : UInt32 = 0
        getter phys_page_dir

        # interrupt frame for preemptive multitasking
        @frame : IdtData::Registers | Nil = nil
        property frame

        MAX_FD = 16
        getter fds

        def initialize(&on_setup_paging)
            # file descriptors
            # BUG: must be initialized here or the GC won't catch it
            @fds = GcArray(FileDescriptor).new MAX_FD

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

            # setup pages
            yield self

            if Multiprocessing.first_process.nil?
                Multiprocessing.first_process = self
            else
                @next_process = Multiprocessing.first_process
                Multiprocessing.first_process = self
            end

            if !last_page_dir.null?
                Paging.disable
                Paging.current_page_dir = last_page_dir
                Paging.enable
            end

            Idt.enable
        end

        def switch
            Multiprocessing.current_process = self
            Idt.disable
            dir = @phys_page_dir # this must be stack allocated
            # because it's placed in the virtual kernel heap
            panic "page dir is nil" if dir == 0
            Paging.disable
            Paging.current_page_dir = Pointer(PageStructs::PageDirectory).new(dir.to_u64)
            Paging.enable
            Idt.enable
            Kernel.kswitch_usermode
        end

        # new register frame for multitasking
        def new_frame
            frame = IdtData::Registers.new
            # Data segment selector
            frame.ds = 0x23u32
            # Stack
            frame.useresp = USER_STACK_TOP
            # Pushed by the processor automatically.
            frame.eip = 0x8000_0000u32
            frame.cs = 0x1Bu32
            frame.eflags = 0x212u32
            frame.ss = 0x23u32
            @frame = frame
            frame
        end

        # file descriptors
        def install_fd(node : VFSNode) : Int32
            i = 0
            f = fds.not_nil!
            while i < MAX_FD
                if f[i].nil?
                    f[i] = FileDescriptor.new node
                    return i
                end
                i += 1
            end
            255
        end

        def get_fd(i : Int32) : FileDescriptor | Nil
            return nil if i > MAX_FD || i < 0
            fds[i]
        end

    end

    # round robin scheduling algorithm
    def next_process : Process | Nil
        return nil if @@current_process.nil?
        proc = @@current_process.not_nil!
        @@current_process = proc.next_process
        if @@current_process.nil?
            @@current_process = @@first_process
        end
        @@current_process
    end

    def setup_tss
        esp0 = 0u32
        asm("mov %esp, $0;" : "=r"(esp0) :: "volatile")
        Kernel.kset_stack esp0
    end

end