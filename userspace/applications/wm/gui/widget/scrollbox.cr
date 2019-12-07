class G::ScrollBox < G::Widget

  getter text, bitmap
  def initialize(@x : Int32, @y : Int32,
                 @width : Int32, @height : Int32)
    @bitmap = Painter.create_bitmap(@width, @height)
    draw_event
  end

  @offset_y = 0

  @main_widget : G::Widget? = nil
  getter main_widget

  def main_widget=(@main_widget : G::Widget)
    main_widget = @main_widget.not_nil!
    main_widget.app = @app
  end

  @bgcolor : UInt32 = 0x0
  property bgcolor

  def resize(@width : Int32, @height : Int32)
    @bitmap = Painter.resize_bitmap(@bitmap, @width, @height)
  end

  def draw_event
    if widget = @main_widget
      Painter.blit_img  @bitmap,
                        @width, @height,
                        widget.bitmap,
                        widget.width, widget.height,
                        0, 0,
                        0, @offset_y
    end
  end

  def mouse_event(ev : G::MouseEvent)
    if ev.scroll_delta != 0 && (widget = @main_widget)
      @offset_y += ev.scroll_delta * 10
      @offset_y = Math.min(Math.max(@offset_y, 0), widget.height - @height)
      @app.not_nil!.redraw
    end
    #if main_widget = @main_widget
    #  main_widget.mouse_event ev
    #end
  end

end
