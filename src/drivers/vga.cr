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
    end

    def putc(x, y, fg, bg, a)
        BUFFER[y * SCREEN_WIDTH + x] = color_code(fg, bg, a)
    end

    def putc(ch : UInt8)
        if ch == '\n'.ord.to_u8
            VGA_STATE.newline
            return
        end
        putc(VGA_STATE.cx, VGA_STATE.cy, VGA_STATE.fg, VGA_STATE.bg, ch)
        VGA_STATE.advance
    end

    def getc
        0
    end

end

# HACK?: store VgaState separate from VgaInstance
# because for some reason its state variables get reset
# whenever puts is called
private struct VgaState
    @cx : UInt8 = 0
    @cy : UInt8 = 0
    @fg : VgaColor = VgaColor::White
    @bg : VgaColor = VgaColor::Black

    def cx; @cx; end
    def cy; @cy; end
    def fg; @fg; end
    def bg; @bg; end

    @[AlwaysInline]
    def advance
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

    @[AlwaysInline]
    def newline
        @cx = 0
        @cy += 1
    end

end

VGA = VgaInstance.new
VGA_STATE = VgaState.new