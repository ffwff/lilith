class G::Label < G::Widget

  getter bitmap
  def initialize(@x : Int32, @y : Int32,
                 @text : String)
    @width = G::Fonts.text_width(text)
    @height = G::Fonts::HEIGHT
    @bitmap = Painter.create_bitmap(@width, @height)
    G::Fonts.blit self, 0, 0, @text
  end

end
