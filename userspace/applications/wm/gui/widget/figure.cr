class G::Figure < G::Widget
  def self.new(x : Int32, y : Int32, path : String, text : String? = nil)
    new x, y, Painter.load_png(path).not_nil!, text
  end

  def initialize(@x : Int32, @y : Int32, @img_bitmap : Painter::Bitmap, @text : String? = nil)
    if text = @text
      width = Math.max(img_bitmap.width, G::Fonts.text_width(text))
      height = img_bitmap.height + G::Fonts.text_height(text)
      @bitmap = Painter::Bitmap.new(width, height)
      redraw
    else
      @bitmap = @img_bitmap
    end
  end

  def redraw
    Painter.blit_img bitmap!,
      @img_bitmap, 0, 0
    if text = @text
      G::Fonts.blit self, ((width - G::Fonts.text_width(text)) // 2), @img_bitmap.height, text
    end
  end
end
