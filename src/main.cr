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
require "./alloc/*"
require "./multiprocessing/*"

lib Kernel
  fun ksyscall_setup
  fun ksetup_fxsave_region_base

  $fxsave_region_ptr : UInt8*
  $fxsave_region_base_ptr : UInt8*
  $kernel_end : Void*
  $text_start : Void*; $text_end : Void*
  $data_start : Void*; $data_end : Void*
  $stack_start : Void*; $stack_end : Void*
end

fun kmain(mboot_magic : UInt32, mboot_header : Multiboot::MultibootInfo*)
  if mboot_magic != MULTIBOOT_BOOTLOADER_MAGIC
    panic "Kernel should be booted from a multiboot bootloader!"
  end

  Multiprocessing.fxsave_region = Kernel.fxsave_region_ptr
  Multiprocessing.fxsave_region_base = Kernel.fxsave_region_base_ptr
  Kernel.ksetup_fxsave_region_base

  Console.puts "Booting lilith...\n"

  Console.puts "initializing gdtr...\n"
  Gdt.init_table

  # drivers
  Pit.init_device

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
  Gc._init Kernel.data_start.address,
    Kernel.data_end.address,
    Kernel.stack_start.address,
    Kernel.stack_end.address

  # processes
  Gdt.stack = Kernel.stack_end
  Gdt.flush_tss
  Kernel.ksyscall_setup

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

  # time
  Time.stamp = RTC.unix

  # initial rootfs
  Multiprocessing.procfs = ProcFS.new
  RootFS.append(Multiprocessing.procfs.not_nil!)
  RootFS.append(KbdFS.new(Keyboard.new))
  RootFS.append(MouseFS.new(Mouse.new))
  RootFS.append(ConsoleFS.new)
  RootFS.append(SerialFS.new)
  RootFS.append(FbdevFS.new)
  RootFS.append(PipeFS.new)
  RootFS.append(TmpFS.new)

  # file systems
  main_bin : VFSNode? = nil
  if (mbr = MBR.read(Ide.device(0)))
    Console.puts "found MBR header...\n"
    fs = Fat16FS.new Ide.device(0), mbr.to_unsafe.value.partitions[0]
    fs.root.each_child do |node|
      if node.name == "main"
        main_bin = node
      end
    end
    RootFS.append(fs)
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
    argv_0 << "/main"
    argv.push argv_0

    udata = Multiprocessing::Process::UserData
      .new(argv,
        main_path,
        fs.not_nil!.root)
    udata.setenv(GcString.new("PATH"), GcString.new("/hd0/bin"))

    case main_bin.not_nil!.spawn(udata)
    when VFS_ERR
      panic "unable to load main!"
    when VFS_WAIT
      fs.not_nil!.queue.not_nil!
        .enqueue(VFSMessage.new(udata, main_bin))
    end

    Idt.status_mask = false
    # switch to pid 1
    Multiprocessing.first_process.not_nil!
      .next_process.not_nil!
      .initial_switch
  end
end
