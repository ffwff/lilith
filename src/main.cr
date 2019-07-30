require "./core.cr"
require "./drivers/core/*"
require "./drivers/arch/*"
require "./drivers/**"
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

lib Kernel
  fun ksyscall_setup
  fun kidle_loop
end

#
ROOTFS = RootFS.new

fun kmain(
  fxsave_region : UInt8*,
  kernel_end : Void*,
  text_start : Void*, text_end : Void*,
  data_start : Void*, data_end : Void*,
  stack_end : Void*, stack_start : Void*,
  mboot_magic : UInt32, mboot_header : Multiboot::MultibootInfo*
)
  if mboot_magic != MULTIBOOT_BOOTLOADER_MAGIC
    panic "Kernel should be booted from a multiboot bootloader!"
  end

  Multiprocessing.fxsave_region = fxsave_region

  # setup memory management
  VGA.puts "Booting lilith...\n"
  KERNEL_ARENA.start_addr = stack_end.address.to_u32 + 0x1000

  VGA.puts "initializing gdtr...\n"
  Gdt.init_table

  # drivers
  pit = PitInstance.new

  # interrupt tables
  VGA.puts "initializing idt...\n"
  Idt.init_interrupts
  Idt.init_table

  # paging, &block
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
  LibGc.init data_start.address.to_u32, data_end.address.to_u32, stack_end.address.to_u32

  #
  ide = nil

  VGA.puts "checking PCI buses...\n"
  PCI.check_all_buses do |device, vendor_id, device_id|
    Serial.puts "device: "
    device.to_s Serial, 16
    Serial.puts ", vendor_id: "
    vendor_id.to_s Serial, 16
    Serial.puts ", device_id: "
    device_id.to_s Serial, 16
    Serial.puts "\n"
    if Ide.pci_device?(vendor_id, device_id)
      ide = Ide.new
    elsif BGA.pci_device?(vendor_id, device_id)
      BGA.init_controller
    end
  end

  ide = ide.not_nil!
  ide.init_controller

  kbd = Keyboard.new
  ROOTFS.append(KbdFS.new(kbd))
  ROOTFS.append(VGAFS.new)

  mbr = MBR.read_ata(ide.device(0))
  main_bin : VFSNode? = nil
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

  idle_process = Multiprocessing::Process.new(nil, false) do |process|
    process.initial_eip = (->Kernel.kidle_loop).pointer.address.to_u32
  end

  if main_bin.nil?
    VGA.puts "no main.bin detected.\n"
  else
    VGA.puts "executing MAIN.BIN...\n"
    argv = GcArray(GcString).new 0
    argv.push GcString.new("/ata0/main.bin")
    udata = Multiprocessing::Process::UserData
              .new(argv,
                GcString.new("/ata0"),
                fs.not_nil!.root)
    m_process = Multiprocessing::Process.new(udata) do |process|
      if (err = ElfReader.load(process, main_bin.not_nil!)).nil?
        argv_builder = ArgvBuilder.new process
        argv.each do |arg|
          argv_builder.from_string arg.not_nil!
        end
        argv_builder.build
        true
      else
        panic "unable to load main.bin: ", err, "\n"
      end
    end
    Idt.status_mask = false
    Multiprocessing.setup_tss
    m_process.initial_switch
  end

  while true
  end
end
