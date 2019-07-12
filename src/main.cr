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
require "./userspace/elf.cr"
require "./userspace/mmap_list.cr"

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
    if mbr.header[0] == 0x55 && mbr.header[1] == 0xaa
        VGA.puts "found MBR header...\n"
        fs = Fat16FS.new mbr.partitions[0]
        fs.not_nil!.root.each_child do |node|
            Serial.puts "node: ", node.name, "\n"
            if node.name == "MAIN.BIN"
                main_bin = node
            end
        end
    end

    VGA.puts "setting up syscalls...\n"
    Kernel.ksyscall_setup

    if main_bin.nil?
        VGA.puts "no rootfs detected.\n"
    else
        VGA.puts "executing MAIN.BIN...\n"
        m_process = Multiprocessing::Process.new do |proc|
            vfs = main_bin.not_nil!
            fs = fs.not_nil!
            mmap_list = MemMapList.new
            mmap_node : MemMapNode | Nil = nil
            mmap_page_idx = 0u32

            ElfReader.read(vfs, fs) do |data|
                case data
                when ElfStructs::Elf32Header
                    data = data.as(ElfStructs::Elf32Header)
                    Serial.puts "offset: ", data.e_phoff, "\n"
                    Serial.puts "sz: ", data.e_phentsize, "\n"
                    Serial.puts "num: ", data.e_phnum, "\n"
                when ElfStructs::Elf32ProgramHeader
                    data = data.as(ElfStructs::Elf32ProgramHeader)
                    if data.p_memsz > 0
                        ins_node = MemMapNode.new(data.p_offset, data.p_filesz, data.p_vaddr, data.p_memsz)
                        if mmap_node.nil?
                            mmap_node = ins_node
                        end
                        mmap_list.append ins_node
                    end
                    case data.p_type
                    when ElfStructs::Elf32PType::LOAD
                        npages = data.p_memsz.div_ceil 4096
                        panic "can't map to lower memory range" if data.p_vaddr < 0x8000_0000
                        Paging.alloc_page_pg data.p_vaddr, true, true, npages
                    when ElfStructs::Elf32PType::GNU_STACK
                        Paging.alloc_page_pg proc.stack_bottom, true, true, 1
                    else
                        panic "unsupported"
                    end
                when Tuple(UInt32, UInt8)
                    offset, byte = data.as(Tuple(UInt32, UInt8))
                    if !mmap_node.nil?
                        mmap_node = mmap_node.not_nil!
                        if offset >= mmap_node.file_offset && offset < mmap_node.file_offset + mmap_node.filesz
                            ptr = Pointer(UInt8).new(mmap_node.vaddr.to_u64)
                            Serial.puts ptr, " ", mmap_page_idx, " ", byte, "\n"
                            ptr[mmap_page_idx] = byte
                            mmap_page_idx += 1
                        elsif mmap_page_idx == mmap_node.filesz + 1
                            mmap_page_idx = 0
                            mmap_node = mmap_node.next_node
                        end
                    end
                end
            end
        end
        Multiprocessing.setup_tss
        m_process.switch
    end

    VGA.puts "done...\n"
    while true
    end

end