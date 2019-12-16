module G::Fonts
  extend self

  private WIDTH  = 8
  private HEIGHT = 8

  def text_width(str : String)
    str.size * WIDTH
  end

  def chars_per_col(col : Int)
    col // WIDTH
  end

  def text_height(str : String)
    HEIGHT
  end

  def chars_per_row(row : Int)
    row // HEIGHT
  end

  def blit(db : UInt32*,
           dw : Int, dh : Int,
           sx : Int, sy : Int, ch : Char)
    if bitmap = FONT8x8[ch.ord]?
      WIDTH.times do |cx|
        HEIGHT.times do |cy|
          dx = sx + cx
          dy = sy + cy
          next if dy >= dh || dx >= dw
          if (bitmap[cy] & (1 << cx)) != 0
            db[dy * dw + dx] = 0x00FFFFFF
          end
        end
      end
    end
  end

  def blit(db : UInt32*,
           dw : Int, dh : Int,
           sx : Int, sy : Int, str : String)
    cx = sx
    str.each_char do |ch|
      blit db, dw, dh, cx, sy, ch
      cx += WIDTH
    end
  end

  def blit(widget : G::Widget,
           cx : Int, cy : Int, ch : Char)
    blit widget.bitmap!,
      cx, cy,
      ch
  end

  def blit(widget : G::Widget,
           cx : Int, cy : Int, str : String)
    blit widget.bitmap!,
      cx, cy,
      str
  end

  def blit(bitmap : Painter::Bitmap,
           cx : Int, cy : Int, ch : Char)
    blit bitmap.to_unsafe,
      bitmap.width, bitmap.height,
      cx, cy,
      ch
  end

  def blit(bitmap : Painter::Bitmap,
           cx : Int, cy : Int, str : String)
    blit bitmap.to_unsafe,
      bitmap.width, bitmap.height,
      cx, cy,
      str
  end

end
