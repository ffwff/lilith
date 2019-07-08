require "./core.cr"
require "./drivers/serial.cr"
require "./drivers/vga.cr"
require "./drivers/pit_timer.cr"
require "./drivers/keyboard.cr"
require "./arch/gdt.cr"
require "./arch/idt.cr"
require "./arch/paging.cr"
require "./arch/multiboot.cr"
require "./alloc/alloc.cr"
require "./alloc/gc.cr"

private lib Kernel
    $pmalloc_start : Void*
end

class Kurasu < Gc
    def initialize(@dbg = 0xdeadbeef)
    end
end

class A2 < Gc
    def initialize
        @dbg1 = Kurasu.new 0xa0baa0ba
        @dbg2 = Kurasu.new 0xabababab
    end
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
    Kernel.pmalloc_start = Pointer(Void).new(Paging.aligned(kernel_end.address.to_u32).to_u64)

    VGA.puts "initializing gdtr...\n"
    Gdt.init_table

    # interrupt tables
    VGA.puts "initializing idt...\n"
    Idt.init_interrupts
    Idt.init_table

    # paging
    VGA.puts "initializing paging...\n"
    Paging.init_table(text_start, text_end,
                    data_start, data_end,
                    stack_start, stack_end,
                    mboot_header)


    VGA.puts "enabling interrupts...\n"
    #Idt.enable

    #
    VGA.puts "initializing kernel garbage collector...\n"
    LibGc.init data_start.address.to_u32, data_end.address.to_u32, stack_start.address.to_u32

    #
    x = Kurasu.new
    Serial.puts "x: ",x.crystal_type_id, "\n"
    y = A2.new
    Serial.puts "y: ",y.crystal_type_id, "\n"
    Serial.puts "z: ",Kurasu.new(0xFFFFFFFF).crystal_type_id, "\n"
    z = Kurasu.new(0xFFFFFFFF)
    Serial.puts "a: ",z.crystal_type_id, "\n"

    # LibGc.cycle
    # Serial.puts LibGc, "\n---\n"
    # LibGc.cycle
    # Serial.puts LibGc, "\n---\n"
    # x = 0
    # LibGc.cycle
    # Serial.puts LibGc, "\n"
    # Serial.puts pointerof(x), " ", pointerof(y), " ", pointerof(z), "\n"
    # LibGc.cycle
    # Serial.puts LibGc, "\n"

    #LibGc.cycle
    #Serial.puts LibGc, "\n"

    #x = KERNEL_ARENA.malloc(16)
    #Serial.puts "ptr: ", Pointer(Void).new(x.to_u64), "\n"
    #KERNEL_ARENA.free x.to_u32
    #x = KERNEL_ARENA.malloc(16)
    #Serial.puts "ptr: ", Pointer(Void).new(x.to_u64), "\n"
    #KERNEL_ARENA.free x.to_u32

    #Serial.puts "ptr: ", Pointer(Void).new(KERNEL_ARENA.malloc(16).to_u64), "\n"
    #Serial.puts "ptr: ", Pointer(Void).new(KERNEL_ARENA.malloc(16).to_u64), "\n"
    #Serial.puts "ptr: ", Pointer(Void).new(KERNEL_ARENA.malloc(32).to_u64), "\n"

    VGA.puts "done...\n"
    while true
    end

end