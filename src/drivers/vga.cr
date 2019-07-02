require "./io_driver.cr"

SCREEN_WIDTH = 80
SCREEN_HEIGHT = 25

enum VgaColor : UInt16
    Black = 0
    Blue = 1
    Green = 2
    Cyan = 3
    Red = 4
    Magenta = 5
    Brown = 6
    LightGray = 7
    DarkGray = 8
    LightBlue = 9
    LightGreen = 10
    LightCyan = 11
    LightRed = 12
    Pink = 13
    Yellow = 14
    White = 15
end

private struct VgaInstance < IoDriver

    def color_code(fg : VgaColor, bg : VgaColor, char : UInt8) UInt16
        attrib = (bg.value.unsafe_shl(4)) | fg.value
        attrib.unsafe_shl(8) | char.to_u8!
    end

    # init
    BUFFER = Pointer(UInt16).new(0xb8000)
    def initialize
        SCREEN_WIDTH.times do |x|
            SCREEN_HEIGHT.times do |y|
                BUFFER[y*SCREEN_WIDTH + x] = 0
            end
        end
        @cx = 0
        @cy = 0
        @fg = VgaColor::White
        @bg = VgaColor::Black
    end

    def putc(x, y, fg, bg, a)
        BUFFER[y * SCREEN_WIDTH + x] = color_code(fg, bg, a)
    end

    def putc(ch)
        if ch == '\n'.ord.to_u8
            @cy += 1
            @cx = 0
            return
        end
        putc(@cx, @cy, @fg, @bg, ch)
        if @cx == SCREEN_WIDTH
            @cx = 0
            @cy += 1
        else
            @cx += 1
        end
        if @cy == SCREEN_HEIGHT
            return
        end
    end

    def getc
        0
    end

end

Vga = VgaInstance.new