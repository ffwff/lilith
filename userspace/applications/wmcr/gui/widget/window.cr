class G::Window < G::Widget

  getter x, y, width, height

  @wm_window : Wm::Window? = nil
  getter wm_window

  @main_widget : G::Widget? = nil
  getter main_widget

  def main_widget=(@main_widget : G::Widget)
    @main_widget.not_nil!.app = @app
  end

  def initialize(@x : Int32, @y : Int32,
                 @width : Int32, @height : Int32)
  end

  def bitmap
    @wm_window.not_nil!.bitmap
  end

  def setup_event
    @wm_window = app.client.create_window(@x, @y, @width, @height).not_nil!
  end

  def draw_event
    if main_widget = @main_widget
      main_widget.draw_event
      unless main_widget.bitmap.null?
        Painter.blit_img bitmap, @width, @height,
                         main_widget.bitmap,
                         main_widget.width, main_widget.height,
                         0, 0
      end
    end
  end

end
