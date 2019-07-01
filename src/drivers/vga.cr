require "./serial.cr"

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

private struct VgaInstance

    def color_code(fg : VgaColor, bg : VgaColor, char : UInt8) UInt16
        attrib = (bg.value.unsafe_shl(4)) | fg.value
        attrib.unsafe_shl(8) | char.to_u8!
    end

    # init
    def initialize
        @buffer = Pointer(UInt16).new(0xb8000)
        SCREEN_WIDTH.times do |x|
            SCREEN_HEIGHT.times do |y|
                @buffer[y*SCREEN_WIDTH + x] = 0
            end
        end
    end

    def unsafe_write(x : UInt16, y : UInt16, a : UInt16)
        @buffer[y * SCREEN_WIDTH + x] = a
    end

    def write_char(x, y, fg, bg, a)
        @buffer[y * SCREEN_WIDTH + x] = color_code(fg, bg, a).to_u16!
    end

    def puts(x, y, fg, bg, s)
        cx = x
        cy = y
        s.each_char do |ch|
            write_char(cx, cy, fg, bg, ch)
            if cx == SCREEN_WIDTH
                cx = 0
                cy += 1
            elsif cy == SCREEN_HEIGHT
                return
            end
            cx += 1
        end
    end

end

VGA = VgaInstance.new