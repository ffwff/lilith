class G::WindowDecoration < G::Widget

  @main_widget : G::Widget? = nil
  getter main_widget

  def main_widget=(@main_widget : G::Widget)
    x, y, width, height = calculate_main_dimensions
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

  def calculate_main_dimensions
    x = 3
    y = 15
    width = @width - 6
    height = @height - y - 3
    {x, y, width, height}
  end

  FOCUSED_BORDER = 0xffffff
  UNFOCUSED_BORDER = 0x999999

  @focused = true
  def border_color
    @focused ? FOCUSED_BORDER : UNFOCUSED_BORDER
  end

  def draw_event
    Painter.blit_rect @bitmap,
                      @width, @height,
                      @width, @height,
                      0, 0, 0x3a434b
    Painter.blit_rect @bitmap,
                      @width, @height,
                      @width, 1,
                      0, 0, border_color
    Painter.blit_rect @bitmap,
                      @width, @height,
                      @width, 1,
                      0, @height - 1, border_color
    Painter.blit_rect @bitmap,
                      @width, @height,
                      1, @height,
                      0, 0, border_color
    Painter.blit_rect @bitmap,
                      @width, @height,
                      1, @height,
                      @width - 1, 0, border_color
    if (title = @title)
      tx, ty = (@width - G::Fonts.text_width(title)) // 2, 3
      G::Fonts.blit self, tx, ty, title
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

  def wm_message_event(ev : Wm::IPC::Message)
    case ev
    when Wm::IPC::Data::RefocusEvent
      @last_mouse_x = -1
      @last_mouse_y = -1
      @focused = ev.focused > 0
      @app.not_nil!.redraw
    end
  end

  @last_mouse_x = -1
  @last_mouse_y = -1
  def mouse_event(ev : G::MouseEvent)
    if ev.modifiers.includes?(Wm::IPC::Data::MouseEventModifiers::LeftButton) &&
        (@last_mouse_x != -1 && @last_mouse_y != -1)
      delta_x = ev.x - @last_mouse_x
      delta_y = ev.y - @last_mouse_y
      if delta_x != 0 || delta_y != 0
        new_x = @app.not_nil!.x + delta_x
        new_y = @app.not_nil!.y + delta_y
        @app.not_nil!.move(new_x, new_y)
      end
    end
    @last_mouse_x = ev.x
    @last_mouse_y = ev.y
  end
end
