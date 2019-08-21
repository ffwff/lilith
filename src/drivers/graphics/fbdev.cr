lib Kernel
  $fb_fonts : UInt8[8][127]
end

private struct FbdevInstance < OutputDriver

  def putchar(ch : UInt8)
    if ch == '\r'.ord.to_u8
      return
    elsif ch == '\n'.ord.to_u8
      FbdevState.newline
      return
    elsif ch == 8u8
      FbdevState.backspace
      FbdevState.putc(FbdevState.cx, FbdevState.cy, ' '.ord.to_u8)
      return
    end
    if FbdevState.cy >= FbdevState.cheight
      FbdevState.scroll
    end
    FbdevState.putc(FbdevState.cx, FbdevState.cy, ch)
    FbdevState.advance
  end

  def putc(ch : UInt8)
    ansi_handler = FbdevState.ansi_handler
    if ansi_handler.nil?
      return putchar(ch)
    end
    seq = ansi_handler.parse ch
    case seq
    when AnsiHandler::CsiSequence
      case seq.type
      when AnsiHandler::CsiSequenceType::EraseInLine
        if seq.arg_n == 0 && FbdevState.cy < FbdevState.cwidth - 1
          x = FbdevState.cx
          while x < VGA_WIDTH
            FbdevState.putc(x, FbdevState.cy, ' '.ord.to_u8)
            x += 1
          end
        end
      when AnsiHandler::CsiSequenceType::MoveCursor
        FbdevState.cx = clamp(seq.arg_m.not_nil!.to_i32 - 1, 0, FbdevState.cwidth)
        FbdevState.cy = clamp(seq.arg_n.not_nil!.to_i32 - 1, 0, FbdevState.cheight)
      end
    when UInt8
      putchar seq
    end
  end

  def newline
    FbdevState.newline
  end

end

Fbdev = FbdevInstance.new

FB_ASCII_FONT_WIDTH = 8
FB_ASCII_FONT_HEIGHT = 8

module FbdevState
  extend self

  @@cx = 0
  @@cy = 0
  @@fg = 0
  @@bg = 0
  
  def cx; @@cx; end
  def cy; @@cy; end
  def fg; @@fg; end
  def bg; @@bg; end
  
  def cx=(@@cx); end
  def cy=(@@cy); end
  def fg=(@@fg); end
  def bg=(@@bg); end

  @@ansi_handler : AnsiHandler? = nil
  def ansi_handler
    if !Multiprocessing.current_process.nil? && @@ansi_handler.nil?
      # TODO better way of initializing this
      @@ansi_handler = AnsiHandler.new
    end
    @@ansi_handler
  end

  def advance
    if @@cx >= @@cwidth
      newline
    else
      @@cx += 1
    end
  end

  def backspace
    if @@cx == 0 && @@cy > 0
      @@cx = @@cwidth
      @@cy -= 1
    elsif @@cx > 0
      @@cx -= 1
    end
  end

  def newline
    if @@cy == @@cheight
      wrapback
    end
    @@cx = 0
    @@cy += 1
  end

  def wrapback
    @@cx = 0
    @@cy = @@cheight - 1
  end

  @@cwidth = 0
  def cwidth
    @@cwidth
  end

  @@width = 0
  def width
    @@width
  end
  
  @@cheight = 0
  def cheight
    @@cheight
  end

  @@height = 0
  def height
    @@height
  end

  # physical framebuffer location
  @@buffer = Pointer(UInt32).null
  def buffer
    @@buffer
  end
  def buffer=(@@buffer)
  end

  private def color(x, y) : UInt32
    r = (x * 255).unsafe_div(@@width).to_u32
    g = (y * 255).unsafe_div(@@height).to_u32
    r.unsafe_shl(16) | g.unsafe_shl(8)
  end

  def init_device(@@width, @@height, @@buffer)
    @@cwidth = @@width.unsafe_div(FB_ASCII_FONT_WIDTH) - 1
    @@cheight = @@height.unsafe_div(FB_ASCII_FONT_HEIGHT) - 1
    @@height.times do |y|
      @@width.times do |x|
        @@buffer[offset x, y] = color x, y
      end
    end
  end

  def offset(x, y)
    y * @@width + x
  end

  def putc(x, y, ch : UInt8)
    return if x > @@cwidth || x < 0
    return if y > @@height || y < 0
    bitmap = Kernel.fb_fonts[ch]?
    return if bitmap.nil?
    bitmap = bitmap.not_nil!
    FB_ASCII_FONT_WIDTH.times do |cx|
      FB_ASCII_FONT_HEIGHT.times do |cy|
        dx = x * FB_ASCII_FONT_WIDTH + cx
        dy = y * FB_ASCII_FONT_HEIGHT + cy
        if (bitmap[cy] & 1.unsafe_shl(cx)) != 0
          @@buffer[offset dx, dy] = 0x00FFFFFF
        else
          @@buffer[offset dx, dy] = color(dx, dy)
        end
      end
    end
  end

  def scroll
    ((@@cheight - 1) * FB_ASCII_FONT_HEIGHT).times do |y|
      (@@cwidth * FB_ASCII_FONT_WIDTH).times do |x|
        @@buffer[offset x, y] = @@buffer[offset x, (y + FB_ASCII_FONT_HEIGHT)]
      end
    end
    FB_ASCII_FONT_HEIGHT.times do |y|
      @@width.times do |x|
        dx, dy = x, ((@@cheight - 1) * FB_ASCII_FONT_HEIGHT + y)
        @@buffer[offset dx, dy] = color(dx, dy)
      end
    end
    wrapback
  end

end