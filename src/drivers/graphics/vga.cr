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
  @[AlwaysInline]
  def color_code(fg : VgaColor, bg : VgaColor, char : UInt8)
    UInt16
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
    enable_cursor 0, 1
    # fill with blank
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


  private def putchar(ch : UInt8)
    if ch == '\r'.ord.to_u8
      return
    elsif ch == '\n'.ord.to_u8
      VgaState.newline
      return
    elsif ch == 8u8
      VgaState.backspace
      putc(VgaState.cx, VgaState.cy, VgaState.fg, VgaState.bg, ' '.ord.to_u8)
      return
    end
    if VgaState.cy >= VGA_HEIGHT
      scroll
    end
    putc(VgaState.cx, VgaState.cy, VgaState.fg, VgaState.bg, ch)
    VgaState.advance
  end

  def putc(ch : UInt8, display? = true)
    ansi_handler = VgaState.ansi_handler
    if ansi_handler.nil?
      return putchar(ch)
    end
    seq = ansi_handler.parse ch
    case seq
    when AnsiHandler::CsiSequence
      case seq.type
      when AnsiHandler::CsiSequenceType::EraseInLine
        blank = color_code VgaState.fg, VgaState.bg, ' '.ord.to_u8
        if seq.arg_n == 0 && VgaState.cy < VGA_HEIGHT - 1
          x = VgaState.cx
          while x < VGA_WIDTH
            @buffer[offset x, VgaState.cy] = blank
            x += 1
          end
        end
      when AnsiHandler::CsiSequenceType::MoveCursor
        VgaState.cx = min(seq.arg_n.not_nil!.to_i32, VGA_WIDTH - 1)
        VgaState.cy = min(seq.arg_m.not_nil!.to_i32, VGA_HEIGHT - 1)
      end
    when UInt8
      if display?
        putchar seq
      end
    end
  end

  def putc_input(ch : UInt8)
    putc ch, VgaState.echo_input?
    move_cursor VgaState.cx, VgaState.cy + 1
  end

  def puts(*args)
    args.each do |arg|
      arg.to_s self
    end
    move_cursor VgaState.cx, VgaState.cy + 1
  end

  # Scrolls the terminal
  private def scroll
    blank = color_code VgaState.fg, VgaState.bg, ' '.ord.to_u8
    (VGA_HEIGHT - 1).times do |y|
      VGA_WIDTH.times do |x|
        @buffer[offset x, y] = @buffer[offset x, (y + 1)]
      end
    end
    VGA_WIDTH.times do |x|
      @buffer[VGA_SIZE - VGA_WIDTH + x] = blank
    end
    VgaState.wrapback
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
    X86.outb(0x3D5, (pos.unsafe_shr(8) & 0xFF).to_u8)
  end
end

module VgaState
  extend self

  @@cx = 0
  @@cy = 0
  @@fg = VgaColor::White
  @@bg = VgaColor::Black
  
  def cx; @@cx; end
  def cy; @@cy; end
  def fg; @@fg; end
  def bg; @@bg; end
  
  def cx=(@@cx); end
  def cy=(@@cy); end
  def fg=(@@fg); end
  def bg=(@@bg); end

  @@echo_input = true
  def echo_input?
    @@echo_input
  end
  def echo_input=(@@echo_input)
  end
  
  @@ansi_handler : AnsiHandler? = nil
  def ansi_handler
    if !Multiprocessing.current_process.nil? && @@ansi_handler.nil?
      # TODO better way of initializing this
      @@ansi_handler = AnsiHandler.new
    end
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
    else
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
end

VGA = VgaInstance.new