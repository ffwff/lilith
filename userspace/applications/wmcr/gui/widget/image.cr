class G::ImageWidget < G::Widget

  def initialize(@x : Int32, @y : Int32,
                 @width : Int32, @height : Int32)
    @bitmap = Painter.create_bitmap(width, height)
  end

  def load_png(path : String)
    Painter.load_png(path, Bytes.new(@bitmap.as(UInt8*), @width * @height * 4))
  end

end
