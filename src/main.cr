require "./drivers/serial.cr"
require "./drivers/vga.cr"

fun kmain()
    while true
        #VGA.unsafe_write 0, 0, 0x0841
        VGA.puts 0, 0, VgaColor::White, VgaColor::Black, "Hello World"
    end
end