class G::WindowDecoration < G::Widget

  @main_widget : G::Widget? = nil
  getter main_widget

  def main_widget=(@main_widget : G::Widget)
    x, y, width, height = calculate_dimensions
    main_widget = @main_widget.not_nil!
    main_widget.move x, y
    main_widget.resize width, height
    main_widget.app = @app
  end

  getter bitmap, title
  def initialize(@x : Int32, @y : Int32,
                 @width : Int32, @height : Int32,
                 @title : String? = nil)
    @bitmap = Painter.create_bitmap(width, height)
  end

  def self.new(window : G::Window, title : String? = nil)
    decoration = new 0, 0, window.width, window.height, title
    window.main_widget = decoration
    decoration
  end

  def calculate_dimensions
    x = 0
    y = 15
    width = @width
    height = @height - y
    {x, y, width, height}
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
    if (main_widget = @main_widget)
      main_widget.draw_event
      Painter.blit_img @bitmap,
                       @width, @height,
                       main_widget.bitmap,
                       main_widget.width, main_widget.height,
                       main_widget.x, main_widget.y
    end
  end

  def io_event(io : IO::FileDescriptor)
    if main_widget = @main_widget
      main_widget.io_event io
    end
  end

  def key_event(ev : G::KeyboardEvent)
    if main_widget = @main_widget
      main_widget.key_event ev
    end
  end

  @last_mouse_x = 0
  @last_mouse_y = 0
  def mouse_event(ev : G::MouseEvent)
    if ev.modifiers.includes?(Wm::IPC::Data::MouseEventModifiers::LeftButton)
      # FIXME: window lags behind mouse on moving
      delta_x = ev.x - @last_mouse_x
      delta_y = ev.y - @last_mouse_y
      if delta_x != 0 || delta_y != 0
        new_x = @app.not_nil!.x + delta_x
        new_y = @app.not_nil!.y + delta_y
        @app.not_nil!.move(new_x, new_y)
      end
      @last_mouse_x = ev.x
      @last_mouse_y = ev.y
    end
  end
end
