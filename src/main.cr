require "./drivers/serial.cr"
require "./drivers/vga.cr"
require "./mem/gdt.cr"
require "./mem/paging.cr"
require "./core/panic.cr"

MULTIBOOT_BOOTLOADER_MAGIC = 0x2BADB002

fun kmain(text_start : UInt32, text_end : UInt32, stack_bottom : UInt32, stack_top : UInt32, mboot_magic : UInt32, mboot_header : UInt8*)
    if mboot_magic != MULTIBOOT_BOOTLOADER_MAGIC
        panic "Kernel should be booted from a multiboot bootloader!"
    end

    Serial.puts "initializing gdtr...\n"
    X86.init_gdtr

    Serial.puts "initializing paging...\n"
    X86.init_paging text_start, text_end, stack_top, stack_bottom

    Serial.puts "done...\n"
    while true
    end
end