class G::Label < G::Widget

  getter text, bitmap
  def initialize(@x : Int32, @y : Int32,
                 @text : String)
    @width = G::Fonts.text_width(text)
    @height = G::Fonts::HEIGHT
    @bitmap = Painter.create_bitmap(@width, @height)
    redraw
  end

  @bgcolor : UInt32 = 0x0
  property bgcolor

  def redraw
    Painter.blit_rect @bitmap,
                      @width, @height,
                      @width, @height,
                      0, 0, @bgcolor
    G::Fonts.blit self, 0, 0, @text
  end

  def text=(@text)
    redraw
  end

end
