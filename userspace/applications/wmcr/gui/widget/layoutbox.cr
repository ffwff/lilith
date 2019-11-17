require "./layout/layout"
require "./layout/*"

class G::LayoutBox < G::Widget

  @layout : G::Layout? = nil
  property layout

  getter bitmap
  def initialize(@x : Int32, @y : Int32,
                 @width : Int32, @height : Int32)
    @bitmap = Painter.create_bitmap(width, height)
  end

  def add_widget(widget : G::Widget)
    @layout.not_nil!.add_widget widget
  end

  def draw_event
    if layout = @layout
      layout.widgets.each do |widget|
        widget.draw_event
        unless widget.bitmap.null?
          Painter.blit_img bitmap, @width, @height,
                           widget.bitmap,
                           widget.width, widget.height,
                           0, 0
        end
      end
    end
  end

end
