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

  getter bitmap
  def initialize(@x : Int32, @y : Int32,
                 @width : Int32, @height : Int32)
    @bitmap = Painter.create_bitmap(width, height)
  end

  def add_widget(widget : G::Widget)
    @layout.not_nil!.add_widget widget
  end

  @bgcolor : UInt32 = 0x0
  property bgcolor

  def resize(@width : Int32, @height : Int32)
    @bitmap = Painter.resize_bitmap @bitmap, @width, @height
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
      Painter.blit_rect @bitmap,
                        @width, @height,
                        @width, @height,
                        0, 0, @bgcolor
      layout.widgets.each do |widget|
        widget.draw_event
        unless widget.bitmap.null?
          Painter.blit_img @bitmap, @width, @height,
                           widget.bitmap,
                           widget.width, widget.height,
                           widget.x, widget.y
        end
      end
    end
  end

  def mouse_event(ev : G::MouseEvent)
    if layout = @layout
      layout.widgets.each do |widget|
        if widget.contains_point?(ev.x, ev.y)
          widget.mouse_event ev
          return
        end
      end
    end
  end

end
