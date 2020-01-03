require "./init.cr"
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
end

MAIN_PATH = "drv"
MAIN_PROGRAM = "main"

private def init_arch
  # processes
  GDT.register_int_stack Kernel.int_stack_end
  GDT.flush_tss
  Kernel.ksyscall_setup

  # interrupts
  Console.print "initializing idt...\n"
  PIC.init_interrupts
  Idt.init_table
  Idt.enable
end

private def init_hardware
  # pci
  Console.print "checking PCI buses...\n"
  PCI.check_all_buses do |bus, device, func, vendor_id|
    device_id = PCI.read_word bus, device, func, PCI::PCI_DEVICE_ID
    if Ide.pci_device?(vendor_id, device_id)
      Ide.init_controller bus, device, func
    elsif BGA.pci_device?(vendor_id, device_id)
      BGA.init_controller bus, device, func
      Console.text_mode = false
    elsif HDA.pci_device?(vendor_id, device_id)
      # HDA.init_controller bus, device, func
    end
  end

  # time
  Time.stamp = RTC.unix

  # ps2 controller
  PS2.init_controller
end

private def init_rootfs
  Multiprocessing.procfs = ProcFS::FS.new
  RootFS.append(Multiprocessing.procfs.not_nil!)
  RootFS.append(KbdFS::FS.new(Keyboard.new))
  RootFS.append(MouseFS::FS.new(Mouse.new))
  RootFS.append(ConsoleFS::FS.new)
  RootFS.append(SerialFS::FS.new)
  RootFS.append(FbdevFS::FS.new)
  RootFS.append(PipeFS::FS.new)
  RootFS.append(TmpFS::FS.new)
  RootFS.append(SocketFS::FS.new)
end

private def init_fs_with_main(fs)
  main_bin = nil
  if !fs.root.dir_populated
    case fs.root.populate_directory
    when VFS_OK
      # ignored
    when VFS_WAIT
      abort "TODO: wait for vfs to pull resources"
    else
      abort "error populating device"
    end
  end
  fs.root.each_child do |node|
    if node.name == MAIN_PROGRAM
      main_bin = node
      break
    end
  end
  RootFS.append(fs)
  main_bin
end

private def init_boot_device
  # file systems
  main_bin : VFS::Node? = nil
  Ide.devices.each do |device|
    if (mbr = MBR.read(device))
      Console.print "found MBR header...\n"
      mbr.to_unsafe.value.partitions.each_with_index do |partition, idx|
        case partition.type
        when 0
          # skipped
        when Fat16FS::MBR_TYPE
          fs = Fat16FS::FS.new device, partition, idx
          if (found_main = init_fs_with_main(fs)) && !main_bin
            RootFS.root_device = fs
            main_bin = found_main
          end
        else
          Serial.print "unknown MBR partition type: ", partition.type, "\n"
        end
      end
    end
  end

  # load main.bin
  if main_bin.nil?
    Console.print "no main detected.\n"
    while true
    end
  else
    Console.print "executing main...\n"

    argv = Array(String).new 0
    argv.push {{ "/#{MAIN_PATH.id}/#{MAIN_PROGRAM.id}" }}

    udata = Multiprocessing::Process::UserData
      .new(argv, {{ "/#{MAIN_PATH.id}" }}, RootFS.root_device.not_nil!.root)
    udata.setenv("PATH", {{ "/#{MAIN_PATH.id}/bin" }})

    case main_bin.not_nil!.spawn(udata)
    when VFS_ERR
      abort "unable to load main!"
    when VFS_WAIT
      RootFS.root_device.not_nil!.queue.not_nil!
        .enqueue(VFS::Message.new(udata, main_bin))
    end

    # switch to pid 1
    Idt.disable # disable so the cpu doesn't interrupt mid context switch
    Idt.switch_processes = true
    Multiprocessing.first_process.not_nil!
      .initial_switch
  end
end

init_arch
init_hardware
init_rootfs
init_boot_device

