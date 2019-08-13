require "./font.cr"

private struct FbdevInstance < OutputDriver

  def putc(ch : UInt8)
    FbdevState.putc(FbdevState.cx, FbdevState.cy, ch)
    FbdevState.advance
  end

  def newline
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
  @@width = 0
  def width
    @@width
  end
  
  @@cheight = 0
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

  def init_device(@@width, @@height, @@buffer)
    @@cwidth = @@width.unsafe_div FB_ASCII_FONT_WIDTH
    @@cheight = @@height.unsafe_div FB_ASCII_FONT_HEIGHT
    @@width.times do |i|
      @@height.times do |j|
        @@buffer[offset i, j] = 0x0000FF00
      end
    end
  end

  def offset(x, y)
    y * @@width + x
  end

  def putc(x, y, ch : UInt8)
    bitmap = FB_ASCII_FONT[ch]
    FB_ASCII_FONT_WIDTH.times do |cx|
      FB_ASCII_FONT_HEIGHT.times do |cy|
        dx = cx * FB_ASCII_FONT_WIDTH
        dy = cy * FB_ASCII_FONT_WIDTH
        if bitmap[cx] & 1.unsafe_shr(cy)
          @@buffer[offset dx, dy] = 0x00FFFFFF
        else
          @@buffer[offset dx, dy] = 0x0
        end
      end
    end
  end

end