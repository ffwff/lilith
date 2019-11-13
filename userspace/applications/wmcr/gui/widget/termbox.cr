class G::Termbox < G::Widget

  @input_fd : IO::FileDescriptor? = nil
  @output_fd : IO::FileDescriptor? = nil
  getter input_fd, output_fd

  # sets the IO device which will be receiving input
  def input_fd=(@input_fd)
    if old_fd = @input_fd
      @app.not_nil!.unwatch_io old_fd
    end
    @app.not_nil!.watch_io @input_fd.not_nil!
  end

  # sets the IO device which output will be displayed
  def output_fd=(@output_fd)
    if old_fd = @output_fd
      @app.not_nil!.unwatch_io old_fd
    end
    @app.not_nil!.watch_io @output_fd.not_nil!
  end

  @bitmap = Pointer(UInt32).null
  getter bitmap
  def initialize(@x : Int32, @y : Int32,
                 width : Int32, height : Int32)
    resize width, height
  end

  def resize(@width : Int32, @height : Int32)
    if @bitmap.null?
      @bitmap = Painter.create_bitmap(@width, @height)
    else
      @bitmap = @bitmap.realloc @width.to_usize * @height.to_usize
    end
    Painter.blit_rect @bitmap,
                      @width, @height,
                      @width, @height,
                      0, 0, 0x00000000
    @cwidth = @width // G::Fonts::WIDTH
    @cheight = @height // G::Fonts::HEIGHT
  end

  @cx = 0
  @cy = 0
  @cwidth = 0
  @cheight = 0
  def putc(ch : UInt8, redraw? = true)
    if @cx == @cwidth
      # TODO
      return
    end
    G::Fonts.blit(self,
                  @cx * G::Fonts::WIDTH,
                  @cy * G::Fonts::HEIGHT,
                  ch.unsafe_chr)
    @cx += 1
    if redraw?
      @app.not_nil!.redraw
    end
  end

  def io_event(io : IO::FileDescriptor)
    if io == @output_fd
      buffer = uninitialized UInt8[128]
      while (nread = io.unbuffered_read(buffer.to_slice)) > 0
        buffer.each_with_index do |u8, i|
          break if i == nread
          putc u8, false
        end
      end
      app.redraw
    end
  end

end

fun breakpoint
asm("nop" ::: "volatile")
end

