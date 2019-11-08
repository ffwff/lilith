VGA_WIDTH  = 80
VGA_HEIGHT = 25
VGA_SIZE   = VGA_WIDTH * VGA_HEIGHT

enum VgaColor : UInt16
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

private struct VgaInstance < OutputDriver
  private def color_code(fg : VgaColor, bg : VgaColor, char : UInt8) : UInt16
    attrib = (bg.value << 4) | fg.value
    (attrib << 8) | char.to_u8
  end

  private def offset(x : Int, y : Int)
    y * VGA_WIDTH + x
  end

  def initialize
    enable_cursor 0, 1
    # fill with blank
    blank = color_code VgaColor::White, VgaColor::Black, ' '.ord.to_u8
    VgaState.lock do |state|
      VGA_HEIGHT.times do |y|
        VGA_WIDTH.times do |x|
          state.buffer[offset x, y] = blank
        end
      end
    end
  end

  # must be called from putc(ch)
  private def putc(state, x : Int32, y : Int32, fg : VgaColor, bg : VgaColor, a : UInt8)
    panic "drawing out of bounds (80x25)!" if x > VGA_WIDTH || y > VGA_HEIGHT
    state.buffer[offset x, y] = color_code(fg, bg, a)
  end

  # must be called from putc(ch)
  private def putchar(state, ch : UInt8)
    if ch == '\r'.ord.to_u8
      return
    elsif ch == '\n'.ord.to_u8
      state.newline
      return
    elsif ch == 8u8
      state.backspace
      putc(state, state.cx, state.cy, state.fg, state.bg, ' '.ord.to_u8)
      return
    end
    if state.cy >= VGA_HEIGHT
      scroll state
    end
    putc(state, state.cx, state.cy, state.fg, state.bg, ch)
    state.advance
  end

  def putc(ch : UInt8)
    VgaState.lock do |state|
      ansi_handler = state.ansi_handler
      if ansi_handler.nil?
        putchar(state, ch)
      else
        seq = ansi_handler.parse ch
        case seq
        when AnsiHandler::CsiSequence
          case seq.type
          when AnsiHandler::CsiSequenceType::EraseInLine
            blank = color_code state.fg, state.bg, ' '.ord.to_u8
            if seq.arg_n == 0 && state.cy < VGA_HEIGHT - 1
              x = state.cx
              while x < VGA_WIDTH
                state.buffer[offset x, state.cy] = blank
                x += 1
              end
            end
          when AnsiHandler::CsiSequenceType::MoveCursor
            state.cx = Math.clamp(seq.arg_m.not_nil!.to_i32 - 1, 0, VGA_WIDTH)
            state.cy = Math.clamp(seq.arg_n.not_nil!.to_i32 - 1, 0, VGA_HEIGHT)
            move_cursor state.cx, state.cy
          end
        when UInt8
          putchar(state, seq)
        end
      end
    end
  end

  def print(*args)
    args.each do |arg|
      arg.to_s self
    end
    VgaState.lock do |state|
      move_cursor state.cx, state.cy + 1
    end
  end

  private def scroll(state)
    blank = color_code state.fg, state.bg, ' '.ord.to_u8
    (VGA_HEIGHT - 1).times do |y|
      VGA_WIDTH.times do |x|
        state.buffer[offset x, y] = state.buffer[offset x, (y + 1)]
      end
    end
    VGA_WIDTH.times do |x|
      state.buffer[VGA_SIZE - VGA_WIDTH + x] = blank
    end
    state.wrapback
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

private module VgaStatePrivate
  extend self

  @@cx = 0
  @@cy = 0
  @@fg = VgaColor::White
  @@bg = VgaColor::Black

  def cx
    @@cx
  end

  def cy
    @@cy
  end

  def fg
    @@fg
  end

  def bg
    @@bg
  end

  def cx=(@@cx); end

  def cy=(@@cy); end

  def fg=(@@fg); end

  def bg=(@@bg); end

  @@ansi_handler = AnsiHandler.new

  def ansi_handler
    @@ansi_handler
  end

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

  @@buffer = Pointer(UInt16).new(0xb8000u64 | PTR_IDENTITY_MASK)

  def buffer
    @@buffer
  end
end

module VgaState
  extend self

  @@lock = Spinlock.new

  def lock(&block)
    @@lock.with do
      yield VgaStatePrivate
    end
  end

  def locked?
    @@lock.locked?
  end
end

VGA = VgaInstance.new
