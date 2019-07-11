require "./core.cr"
require "./drivers/serial.cr"
require "./drivers/vga.cr"
require "./drivers/pit_timer.cr"
require "./drivers/keyboard.cr"
require "./drivers/pci.cr"
require "./drivers/ide.cr"
require "./drivers/mbr.cr"
require "./arch/gdt.cr"
require "./arch/idt.cr"
require "./arch/paging.cr"
require "./arch/multiboot.cr"
require "./alloc/alloc.cr"
require "./alloc/gc.cr"
require "./fs/fat16.cr"
require "./userspace/syscall.cr"
require "./userspace/process.cr"

lib Kernel
    fun ksyscall_setup()
end

fun kmain(kernel_end : Void*,
        text_start : Void*, text_end : Void*,
        data_start : Void*, data_end : Void*,
        stack_start : Void*, stack_end : Void*,
        mboot_magic : UInt32, mboot_header : Multiboot::MultibootInfo*)

    if mboot_magic != MULTIBOOT_BOOTLOADER_MAGIC
        panic "Kernel should be booted from a multiboot bootloader!"
    end

    # drivers
    pit = PitInstance.new
    keyboard = KeyboardInstance.new

    # setup memory management
    VGA.puts "Booting crystal-os...\n"

    VGA.puts "initializing gdtr...\n"
    Gdt.init_table

    # interrupt tables
    VGA.puts "initializing idt...\n"
    Idt.init_interrupts
    Idt.init_table

    # paging
    VGA.puts "initializing paging...\n"
    PMALLOC_STATE.start = Paging.aligned(kernel_end.address.to_u32)
    PMALLOC_STATE.addr = Paging.aligned(kernel_end.address.to_u32)
    Paging.init_table(text_start, text_end,
                    data_start, data_end,
                    stack_start, stack_end,
                    mboot_header)
    VGA.puts "physical memory detected: ", Paging.usable_physical_memory, " bytes\n"

    #
    VGA.puts "initializing kernel garbage collector...\n"
    LibGc.init data_start.address.to_u32, data_end.address.to_u32, stack_start.address.to_u32

    #
    VGA.puts "checking PCI buses...\n"
    PCI.check_all_buses

    mbr = MBR.read_ide
    fs : VFS | Nil = nil
    main_bin : VFSNode | Nil = nil
    penpen_bin : VFSNode | Nil = nil
    if mbr.header[0] == 0x55 && mbr.header[1] == 0xaa
        VGA.puts "found MBR header...\n"
        fs = Fat16FS.new mbr.partitions[0]
        fs.not_nil!.root.each_child do |node|
            VGA.puts "node: ", node.name, "\n"
            if node.name == "MAIN.BIN"
                main_bin = node
            elsif node.name == "PENPEN.BIN"
                penpen_bin = node
            end
            #VGA.puts "contents: "
            #node.read(fs) do |ch|
            #    VGA.puts ch.unsafe_chr
            #end
            #VGA.puts "\n"
        end
    end

    VGA.puts "setting up syscalls...\n"
    Kernel.ksyscall_setup

    if main_bin.nil?
        VGA.puts "no rootfs detected.\n"
    else
        VGA.puts "executing MAIN.BIN...\n"
        m_process = Multiprocessing::Process.new main_bin.not_nil!, fs.not_nil!
        Serial.puts "M_PR: ", m_process.phys_page_dir, "\n"
        p_process = Multiprocessing::Process.new penpen_bin.not_nil!, fs.not_nil!
        Serial.puts "P_PR: ", p_process.phys_page_dir, "\n"
        p_process.switch
    end

    VGA.puts "done...\n"
    while true
    end

end