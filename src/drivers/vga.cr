require "./io_driver.cr"

VGA_WIDTH = 80
VGA_HEIGHT = 25
VGA_SIZE = VGA_WIDTH * VGA_HEIGHT

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

    @[AlwaysInline]
    private def offset(x : Int, y : Int)
        y * VGA_WIDTH + x
    end

    # init
    @buffer : UInt16* = Pointer(UInt16).new(0xb8000)
    def initialize
        blank = color_code VgaColor::White, VgaColor::Black, ' '.ord.to_u8
        VGA_HEIGHT.times do |y|
            VGA_WIDTH.times do |x|
                @buffer[offset x, y] = blank
            end
        end
    end

    def putc(x : Int32, y : Int32, fg : VgaColor, bg : VgaColor, a : UInt8)
        panic "drawing out of bounds (80x25)!" if x > VGA_WIDTH || y > VGA_HEIGHT
        @buffer[offset x, y] = color_code(fg, bg, a)
    end

    def putc(ch : UInt8)
        if ch == '\n'.ord.to_u8
            VGA_STATE.newline
            return
        end
        if VGA_STATE.cy >= VGA_HEIGHT
            scroll
        end
        putc(VGA_STATE.cx, VGA_STATE.cy, VGA_STATE.fg, VGA_STATE.bg, ch)
        VGA_STATE.advance
    end

    def getc
        0
    end

    # Scrolls the terminal
    private def scroll
        blank = color_code VGA_STATE.fg, VGA_STATE.bg, ' '.ord.to_u8
        (VGA_HEIGHT - 1).times do |y|
            VGA_WIDTH.times do |x|
                @buffer[offset x, y] = @buffer[offset x, (y + 1)]
            end
        end
        VGA_WIDTH.times do |x|
            @buffer[VGA_SIZE - VGA_WIDTH + x] = blank
        end
        VGA_STATE.wrapback
    end

end

# HACK?: store VgaState separate from VgaInstance
# because for some reason its state variables get reset
# whenever puts is called
private struct VgaState

    @cx : Int32 = 0
    @cy : Int32 = 0
    @fg : VgaColor = VgaColor::White
    @bg : VgaColor = VgaColor::Black

    def cx; @cx; end
    def cy; @cy; end
    def fg; @fg; end
    def bg; @bg; end

    @[AlwaysInline]
    def advance
        if @cx >= VGA_WIDTH
            newline
        else
            @cx += 1
        end
    end

    def newline
        if @cy == VGA_HEIGHT
            wrapback
        end
        @cx = 0
        @cy += 1
    end

    @[AlwaysInline]
    def wrapback
        @cx = 0
        @cy = VGA_HEIGHT - 1
    end

end

VGA = VgaInstance.new
VGA_STATE = VgaState.new