lib Kernel
  $fb_fonts : UInt8[8][127]
end

private struct FbdevInstance < OutputDriver

  private def putchar(state, ch : UInt8)
    if ch == '\r'.ord.to_u8
      return
    elsif ch == '\n'.ord.to_u8
      state.newline
      return
    elsif ch == 8u8
      state.backspace
      state.putc(state.cx, state.cy, ' '.ord.to_u8)
      return
    end
    if state.cy >= state.cheight
      state.scroll
    end
    state.putc(state.cx, state.cy, ch)
    state.advance
  end

  def putc(ch : UInt8)
    FbdevState.lock do |state|
      ansi_handler = state.ansi_handler
      if ansi_handler.nil?
        putchar(state, ch)
      else
        seq = ansi_handler.parse ch
        case seq
        when AnsiHandler::CsiSequence
          case seq.type
          when AnsiHandler::CsiSequenceType::EraseInLine
            if seq.arg_n == 0 && state.cy < state.cwidth - 1
              x = state.cx
              while x < state.cwidth
                state.putc(x, state.cy, ' '.ord.to_u8)
                x += 1
              end
            end
          when AnsiHandler::CsiSequenceType::MoveCursor
            state.cx = clamp(seq.arg_m.not_nil!.to_i32 - 1, 0, state.cwidth)
            state.cy = clamp(seq.arg_n.not_nil!.to_i32 - 1, 0, state.cheight)
          end
        when UInt8
          putchar(state, seq)
        end
      end
    end
  end

end

Fbdev = FbdevInstance.new

private module FbdevStatePrivate
extend self

  FB_ASCII_FONT_WIDTH = 8
  FB_ASCII_FONT_HEIGHT = 8
  FB_BACK_BUFFER_POINTER = 0xFFFF_8700_0000_0000u64

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
    if @@ansi_handler.nil? && !Multiprocessing.current_process.nil?
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
  @@buffer = Slice(UInt32).null
  def buffer
    @@buffer
  end

  @@back_buffer = Slice(UInt32).null
  def back_buffer
    @@back_buffer
  end

  def init_device(@@width, @@height, ptr)
    @@cwidth = (@@width / FB_ASCII_FONT_WIDTH) - 1
    @@cheight = (@@height / FB_ASCII_FONT_HEIGHT) - 1
    @@buffer = Slice(UInt32).new(ptr, @@width * @@height)
    memset(@@buffer.to_unsafe.as(UInt8*), 0u64,
      @@width.to_usize * @@height.to_usize * sizeof(UInt32).to_usize)

    npages = (@@width.to_usize * @@height.to_usize * sizeof(UInt32).to_usize) / 0x1000
    back_ptr = Paging.alloc_page_pg(FB_BACK_BUFFER_POINTER, true, false, npages)
    @@back_buffer = Slice(UInt32).new(Pointer(UInt32).new(back_ptr), @@width * @@height)
    memset(@@back_buffer.to_unsafe.as(UInt8*), 0u64,
      @@width.to_usize * @@height.to_usize * sizeof(UInt32).to_usize)
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
        if (bitmap[cy] & (1 << cx)) != 0
          @@buffer[offset dx, dy] = 0x00FFFFFF
        else
          @@buffer[offset dx, dy] = 0x0
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
        @@buffer[offset dx, dy] = 0x0
      end
    end
    wrapback
  end

end

module FbdevState
  extend self

  @@lock = Spinlock.new

  def lock(&block)
    @@lock.with do
      yield FbdevStatePrivate
    end
  end

  def locked?
    @@lock.locked?
  end
end