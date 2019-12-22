require "./layout/layout"
require "./layout/*"

class G::LayoutBox < G::Widget

  @layout : G::Layout? = nil
  getter layout
  def layout=(@layout : G::Layout)
    @layout.not_nil!.parent = self
    @layout.not_nil!.app = app
    @layout
  end

  def initialize(@x : Int32, @y : Int32,
                 @width : Int32, @height : Int32)
    @bitmap = Painter::Bitmap.new(width, height)
  end

  def add_widget(widget : G::Widget)
    @layout.not_nil!.add_widget widget
  end

  @bgcolor : UInt32 = 0x0
  property bgcolor

  def resize(@width : Int32, @height : Int32)
    bitmap!.resize @width, @height
    draw_event
  end

  def resize_to_content
    @layout.not_nil!.resize_to_content
  end

  def clear
    @layout.not_nil!.clear
  end

  def draw_event
    if layout = @layout
      Painter.blit_rect bitmap!,
                        0, 0, @bgcolor
      layout.widgets.each do |widget|
        widget.draw_event
        if wbitmap = widget.bitmap
          Painter.blit_img bitmap!,
                           wbitmap,
                           widget.x, widget.y
        end
      end
    end
  end

  def mouse_event(ev : G::MouseEvent)
    if layout = @layout
      layout.widgets.each do |widget|
        if widget.contains_point?(ev.relx, ev.rely)
          widget.mouse_event ev
          return
        end
      end
    end
  end

end
