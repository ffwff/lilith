require "./core/panic.cr"
require "./drivers/serial.cr"
require "./drivers/vga.cr"
require "./mem/gdt.cr"
require "./mem/idt.cr"
require "./mem/paging.cr"

MULTIBOOT_BOOTLOADER_MAGIC = 0x2BADB002

private lib Kernel
    $pmalloc_start : Void*
end

fun kmain(kernel_end : Void*,
        text_start : Void*, text_end : Void*,
        data_start : Void*, data_end : Void*,
        stack_start : Void*, stack_end : Void*,
        mboot_magic : UInt32, mboot_header : UInt8*)
    if mboot_magic != MULTIBOOT_BOOTLOADER_MAGIC
        panic "Kernel should be booted from a multiboot bootloader!"
    end

    # setup memory management
    Kernel.pmalloc_start = kernel_end

    Serial.puts "initializing gdtr...\n"
    Gdt.init_table

    # interrupt tables
    Serial.puts "initializing idt...\n"
    Idt.init_table

    # paging
    Serial.puts "initializing paging...\n"
    Paging.init_table(text_start, text_end,
                    data_start, data_end,
                    stack_start, stack_end)

    Vga.puts "Hello World\n"
    Vga.puts "ABC"

    Serial.puts "done...\n"
    while true
    end
end