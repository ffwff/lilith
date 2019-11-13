module G::Fonts
  extend self

  WIDTH  = 8
  HEIGHT = 8
  def blit(db : UInt32*,
           dw : Int, dh : Int,
           sx : Int, sy : Int, ch : Char)
    if bitmap = FONT8x8[ch.ord]?
      WIDTH.times do |cx|
        HEIGHT.times do |cy|
          dx = sx + cx
          dy = sy + cy
          return if dy >= dh || dx >= dw
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
    blit widget.bitmap,
      widget.width, widget.height,
      cx, cy,
      ch
  end

  def blit(widget : G::Widget,
           cx : Int, cy : Int, str : String)
    blit widget.bitmap,
      widget.width, widget.height,
      cx, cy,
      str
  end

  def text_width(str : String)
    str.size * WIDTH
  end

end
