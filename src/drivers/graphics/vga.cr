VGA_WIDTH  = 80
VGA_HEIGHT = 25
VGA_SIZE   = VGA_WIDTH * VGA_HEIGHT

# A VGA text mode driver which renders output into `0xB8000` (identity mapped at `0xFFFF8000000B8000`).
module VGA
  extend self

  private module Unlocked
    extend self

    @@cx = 0
    @@cy = 0
    @@fg = VGA::Color::White
    @@bg = VGA::Color::Black
    class_property cx
    class_property cy
    class_property fg
    class_property bg

    @@ansi_handler = AnsiHandler.new
    class_getter ansi_handler

    def advance
      if @@cx >= VGA_WIDTH
        newline
      else
        @@cx += 1
      end
    end

    def backspace
      if @@cx == 0 && @@cy > 0
        @@cx = VGA_WIDTH
        @@cy -= 1
      elsif @@cx > 0
        @@cx -= 1
      end
    end

    def newline
      if @@cy == VGA_HEIGHT
        wrapback
      end
      @@cx = 0
      @@cy += 1
    end

    def wrapback
      @@cx = 0
      @@cy = VGA_HEIGHT - 1
    end

    protected def color_code(fg : VGA::Color, bg : VGA::Color, char : UInt8) : UInt16
      attrib = (bg.value << 4) | fg.value
      (attrib << 8) | char.to_u8
    end

    protected def offset(x : Int, y : Int)
      y * VGA_WIDTH + x
    end

    @@buffer = Pointer(UInt16).new(0xb8000u64 | Paging::IDENTITY_MASK)
    class_getter buffer

    def init_device
      enable_cursor 0, 1
      # fill with blank
      blank = color_code VGA::Color::White, VGA::Color::Black, ' '.ord.to_u8
      VGA_HEIGHT.times do |y|
        VGA_WIDTH.times do |x|
          @@buffer[offset x, y] = blank
        end
      end
    end

    def scroll
      blank = color_code @@fg, @@bg, ' '.ord.to_u8
      (VGA_HEIGHT - 1).times do |y|
        VGA_WIDTH.times do |x|
          @@buffer[offset x, y] = @@buffer[offset x, (y + 1)]
        end
      end
      VGA_WIDTH.times do |x|
        @@buffer[VGA_SIZE - VGA_WIDTH + x] = blank
      end
      wrapback
    end

    private def putc(x : Int32, y : Int32, fg : VGA::Color, bg : VGA::Color, a : UInt8)
      abort "drawing out of bounds (80x25)!" if x > VGA_WIDTH || y > VGA_HEIGHT
      @@buffer[offset x, y] = color_code(fg, bg, a)
    end

    private def putchar(ch : UInt8)
      if ch == '\r'.ord.to_u8
        return
      elsif ch == '\n'.ord.to_u8
        newline
        return
      elsif ch == 8u8
        backspace
        putc(cx, cy, fg, bg, ' '.ord.to_u8)
        return
      end
      if cy >= VGA_HEIGHT
        scroll
      end
      putc(cx, cy, fg, bg, ch)
      advance
    end

    def putc(ch : UInt8)
      if @@ansi_handler.nil?
        putchar(ch)
      else
        seq = @@ansi_handler.parse ch
        case seq
        when AnsiHandler::CsiSequence
          case seq.type
          when AnsiHandler::CsiSequenceType::EraseInLine
            blank = color_code @@fg, @@bg, ' '.ord.to_u8
            if seq.arg_n == 0 && @@cy < VGA_HEIGHT - 1
              x = @@cx
              while x < VGA_WIDTH
                @@buffer[offset x, @@cy] = blank
                x += 1
              end
            end
          when AnsiHandler::CsiSequenceType::MoveCursor
            @@cx = Math.clamp(seq.arg_m.not_nil!.to_i32 - 1, 0, VGA_WIDTH)
            @@cy = Math.clamp(seq.arg_n.not_nil!.to_i32 - 1, 0, VGA_HEIGHT)
            move_cursor @@cx, @@cy
          end
        when UInt8
          putchar(seq)
        end
      end
    end

    # Cursor
    def enable_cursor(cursor_start, cursor_end)
      X86.outb(0x3D4, 0x0A)
      X86.outb(0x3D5, (X86.inb(0x3D5) & 0xC0) | cursor_start)
      X86.outb(0x3D4, 0x0B)
      X86.outb(0x3D5, (X86.inb(0x3D5) & 0xE0) | cursor_end)
    end

    def disable_cursor
      X86.outb(0x3D4, 0x0A)
      X86.outb(0x3D5, 0x20)
    end

    def move_cursor(x, y)
      pos = offset x, y
      X86.outb(0x3D4, 0x0F)
      X86.outb(0x3D5, (pos & 0xFF).to_u8)
      X86.outb(0x3D4, 0x0E)
      X86.outb(0x3D5, ((pos >> 8) & 0xFF).to_u8)
    end
  end

  # Initialises the VGA device by clearing the screen and resetting the cursor.
  def init_device
    lock do |state|
      state.init_device
    end
  end

  @@lock = Spinlock.new

  # Locks the VGA device
  def lock(&block)
    @@lock.with do
      yield Unlocked
    end
  end

  # Checks if VGA device is locked
  def locked?
    @@lock.locked?
  end

  # VGA Color
  enum Color : UInt16
    Black      =  0
    Blue       =  1
    Green      =  2
    Cyan       =  3
    Red        =  4
    Magenta    =  5
    Brown      =  6
    LightGray  =  7
    DarkGray   =  8
    LightBlue  =  9
    LightGreen = 10
    LightCyan  = 11
    LightRed   = 12
    Pink       = 13
    Yellow     = 14
    White      = 15
  end

  # Prints a character to screen
  def putc(ch : UInt8)
    lock do |state|
      state.putc ch
    end
  end

  # Prints objects to screen
  def print(*args)
    args.each do |arg|
      arg.to_s self
    end
    lock do |state|
      state.move_cursor state.cx, state.cy + 1
    end
  end
end
