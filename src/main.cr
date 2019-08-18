require "./core.cr"
require "./fs.cr"
require "./drivers/core/*"
require "./drivers/arch/*"
require "./drivers/**"
require "./arch/gdt.cr"
require "./arch/idt.cr"
require "./arch/paging.cr"
require "./arch/multiboot.cr"
require "./arch/cpuid.cr"
require "./alloc/alloc.cr"
require "./alloc/gc.cr"
require "./userspace/syscalls.cr"
require "./userspace/process.cr"
require "./userspace/elf.cr"
require "./userspace/mmap_list.cr"

lib Kernel
  fun ksyscall_setup

  $fxsave_region_ptr : UInt8*
  $kernel_end : Void*
  $text_start : Void*; $text_end : Void*
  $data_start : Void*; $data_end : Void*
  $stack_start : Void*; $stack_end : Void*
end

ROOTFS = RootFS.new

fun kmain(mboot_magic : UInt32, mboot_header : Multiboot::MultibootInfo*)
  if mboot_magic != MULTIBOOT_BOOTLOADER_MAGIC
    panic "Kernel should be booted from a multiboot bootloader!"
  end

  Multiprocessing.fxsave_region = Kernel.fxsave_region_ptr

  Console.puts "Booting lilith...\n"

  Console.puts "initializing gdtr...\n"
  Gdt.init_table

  # drivers
  Pit.init

  # interrupt tables
  Console.puts "initializing idt...\n"
  Idt.init_interrupts
  Idt.init_table
  Idt.status_mask = true

  # paging
  Console.puts "initializing paging...\n"
  # use the physical address of the kernel end for pmalloc
  Pmalloc.start = Paging.aligned(Kernel.kernel_end.address - KERNEL_OFFSET)
  Pmalloc.addr = Pmalloc.start
  Paging.init_table(Kernel.text_start, Kernel.text_end,
                Kernel.data_start, Kernel.data_end,
                Kernel.stack_start, Kernel.stack_end,
                mboot_header)

  Console.puts "physical memory detected: ", Paging.usable_physical_memory, " bytes\n"

  # gc
  Console.puts "initializing kernel garbage collector...\n"
  KernelArena.start_addr = Kernel.stack_end.address + 0x1000
  Gc.init Kernel.data_start.address,
          Kernel.data_end.address,
          Kernel.stack_end.address

  # processes
  Gdt.stack = Kernel.stack_end
  Gdt.flush_tss
  Kernel.ksyscall_setup

  idle_process = Multiprocessing::Process.new do |process|
    process.initial_sp = Kernel.stack_end.address
    process.initial_ip = 0u64
    true
  end

  # hardware
  # pci
  Console.puts "checking PCI buses...\n"
  PCI.check_all_buses do |bus, device, func, vendor_id|
    device_id = PCI.read_field bus, device, func, PCI::PCI_DEVICE_ID, 2
    if Ide.pci_device?(vendor_id, device_id)
      Ide.init_controller
    elsif BGA.pci_device?(vendor_id, device_id)
      BGA.init_controller bus, device, func
      Console.text_mode = false
    end
  end

  # kbd
  kbd = Keyboard.new
  ROOTFS.append(KbdFS.new(kbd))
  ROOTFS.append(VGAFS.new)

  # file systems
  main_bin : VFSNode? = nil
  if (mbr = MBR.read(Ide.device(0)))
    Console.puts "found MBR header...\n"
    fs = Fat16FS.new Ide.device(0), mbr.object.partitions[0]
    fs.root.each_child do |node|
      if node.name == "main"
        main_bin = node
      end
    end
    ROOTFS.append(fs)
  else
    panic "can't boot from this device"
  end

  # load main.bin
  if main_bin.nil?
    Console.puts "no main.bin detected.\n"
    while true
    end
  else
    Console.puts "executing MAIN.BIN...\n"
    main_path = GcString.new("/")
    main_path << fs.not_nil!.name

    argv = GcArray(GcString).new 0
    argv_0 = main_path.clone
    argv_0 << "/main.bin"
    argv.push argv_0

    udata = Multiprocessing::Process::UserData
              .new(argv,
                main_path,
                fs.not_nil!.root)
    m_process = Multiprocessing::Process.spawn_user(main_bin.not_nil!, udata)
    if m_process.nil?
      panic "unable to load main.bin"
    end

    Idt.status_mask = false

    m_process = m_process.not_nil!
    m_process.initial_switch
  end
end
