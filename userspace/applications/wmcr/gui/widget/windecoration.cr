class G::WindowDecoration < G::Widget

  getter x, y, width, height, bitmap, title
  def initialize(@x : Int32, @y : Int32,
                 @width : Int32, @height : Int32,
                 @title : String? = nil)
    @bitmap = Pointer(UInt32).malloc_atomic @width.to_usize * @height.to_usize
  end

  def self.new(window : G::Window, title : String? = nil)
    decoration = new 0, 0, window.width, window.height, title
    window.main_widget = decoration
    decoration
  end

  def draw_event
    Painter.blit_rect @bitmap,
                      @width, @height,
                      @width, @height,
                      0, 0, 0x00ff0000
    if (title = @title)
      tx, ty = (@width - G::Fonts.text_width(title)) // 2, 3
      G::Fonts.blit(self, tx, ty, title)
    end
  end

end
