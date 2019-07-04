require "./cpuio.cr"
require "./io_driver.cr"

private PORT = 0x3F8

private struct SerialImpl < IoDriver

    def initialize
        X86.outb((PORT + 1).to_u16, 0x00.to_u8) # Disable all interrupts
        X86.outb((PORT + 3).to_u16, 0x80.to_u8) # Enable DLAB (set baud rate divisor)
        X86.outb((PORT + 0).to_u16, 0x03.to_u8) # Set divisor to 3 (lo byte) 38400 baud
        X86.outb((PORT + 1).to_u16, 0x00.to_u8) #                  (hi byte)
        X86.outb((PORT + 3).to_u16, 0x03.to_u8) # 8 bits, no parity, one stop bit
        X86.outb((PORT + 2).to_u16, 0xC7.to_u8) # Enable FIFO, clear them, with 14-byte threshold
        X86.outb((PORT + 4).to_u16, 0x0B.to_u8) # IRQs enabled, RTS/DSR set
    end

    #
    def available
        X86.inb((PORT + 5).to_u16) & 1
    end

    def transmit_empty?
        (X86.inb((PORT + 5).to_u16) & 0x20) == 0
    end

    def getc
        X86.inb(PORT.to_u16).to_char
    end

    def putc(a : UInt8)
        X86.outb(PORT.to_u16, a)
    end
end

Serial = SerialImpl.new