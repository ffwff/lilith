lib Kernel
  $fxsave_region_ptr : UInt8*
  $fxsave_region_base_ptr : UInt8*
  $kernel_end : Void*
  $text_start : Void*; $text_end : Void*
  $data_start : Void*; $data_end : Void*
  $stack_start : Void*; $stack_end : Void*
  $int_stack_start : Void*; $int_stack_end : Void*
end

lib LibCrystalMain
  fun __crystal_main(argc : Int32, argv : UInt8**)
end

fun kmain(mboot_magic : UInt32, mboot_header : Multiboot::MultibootInfo*)
  if mboot_magic != MULTIBOOT_BOOTLOADER_MAGIC
    abort "Kernel should be booted from a multiboot bootloader!"
  end

  Multiprocessing.fxsave_region = Kernel.fxsave_region_ptr
  Multiprocessing.fxsave_region_base = Kernel.fxsave_region_base_ptr
  Kernel.ksetup_fxsave_region_base

  VGA.init_device
  Serial.init_device

  Console.print "Booting lilith...\n"

  Console.print "initializing gdtr...\n"
  GDT.init_table

  # timer
  PIT.init_device

  # paging
  Console.print "initializing paging...\n"
  # use the physical address of the kernel end for pmalloc
  Pmalloc.start = Paging.aligned(Kernel.kernel_end.address - Paging::KERNEL_OFFSET)
  Pmalloc.addr = Pmalloc.start
  Paging.init_table(Kernel.text_start, Kernel.text_end,
    Kernel.data_start, Kernel.data_end,
    Kernel.stack_start, Kernel.stack_end,
    Kernel.int_stack_start, Kernel.int_stack_end,
    mboot_header)

  Console.print "physical memory detected: ", Paging.usable_physical_memory, " bytes\n"

  # gc
  Console.print "initializing kernel garbage collector...\n"
  Allocator.init(Kernel.int_stack_end.address + 0x1000)
  GC.init Kernel.stack_start, Kernel.stack_end

  LibCrystalMain.__crystal_main(0, Pointer(UInt8*).null)
end

fun __crystal_once_init : Void*
  Pointer(Void).new 0
end

fun __crystal_once(state : Void*, flag : Bool*, initializer : Void*)
  unless flag.value
    Proc(Nil).new(initializer, Pointer(Void).new 0).call
    flag.value = true
  end
end
