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
require "./fs/vgafs.cr"
require "./fs/kbdfs.cr"
require "./userspace/syscalls.cr"
require "./userspace/process.cr"
require "./userspace/elf.cr"
require "./userspace/mmap_list.cr"
require "./kprocess.cr"

lib Kernel
    fun ksyscall_setup()
end

ROOTFS = RootFS.new

fun kmain(
        fxsave_region : UInt8*,
        kernel_end : Void*,
        text_start : Void*, text_end : Void*,
        data_start : Void*, data_end : Void*,
        stack_start : Void*, stack_end : Void*,
        mboot_magic : UInt32, mboot_header : Multiboot::MultibootInfo*)

    if mboot_magic != MULTIBOOT_BOOTLOADER_MAGIC
        panic "Kernel should be booted from a multiboot bootloader!"
    end

    Multiprocessing.fxsave_region = fxsave_region

    # drivers
    pit = PitInstance.new

    # setup memory management
    VGA.puts "Booting lilith...\n"

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

    ide = (if PCI.has_ide
        Ide.new
    else
        VGA.puts "no IDE controller detected!"
        nil
    end).not_nil!
    ide.init_controller

    keyboard = Keyboard.new
    keyboard.kbdfs = KbdFS.new(keyboard)
    ROOTFS.append(keyboard.kbdfs.not_nil!)

    ROOTFS.append(VGAFS.new)

    mbr = MBR.read_ide(ide.device(0))
    main_bin : VFSNode | Nil = nil
    if mbr.header[0] == 0x55 && mbr.header[1] == 0xaa
        VGA.puts "found MBR header...\n"
        fs = Fat16FS.new ide.device(0), mbr.partitions[0]
        fs.root.each_child do |node|
            if node.name == "main.bin"
                main_bin = node
            end
        end
        ROOTFS.append(fs)
    end

    VGA.puts "setting up syscalls...\n"
    Kernel.ksyscall_setup

    Idt.disable
    Idt.status_mask = true

    k_process = Multiprocessing::Process.new(true) do |proc|
        proc.initial_addr = (->kprocess_loop).pointer.address.to_u32
    end

    if main_bin.nil?
        VGA.puts "no main.bin detected.\n"
    else
        VGA.puts "executing MAIN.BIN...\n"
        m_process = Multiprocessing::Process.new do |proc|
            ElfReader.load(proc, main_bin.not_nil!)
        end

        Idt.status_mask = false
        Multiprocessing.setup_tss
        m_process.initial_switch
    end

    while true
    end

end