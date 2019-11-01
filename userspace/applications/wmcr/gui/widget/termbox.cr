class G::Termbox < G::Widget

  @input_fd = -1
  @output_fd = -1
  property input_fd, output_fd

  getter bitmap
  def initialize(@x : Int32, @y : Int32,
                 @width : Int32, @height : Int32)
    @bitmap = Pointer(UInt32).malloc_atomic @width.to_usize * @height.to_usize
  end

  def resize(@width : Int32, @height : Int32)
    @bitmap = @bitmap.realloc @width.to_usize * @height.to_usize
  end

  def draw_event
    Painter.blit_rect @bitmap,
                      @width, @height,
                      @width, @height,
                      0, 0, 0x00000000
  end

end
