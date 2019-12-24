module G::Sprites
  extend self

  DEC_TOP = "/hd0/share/wm/dec_top.png"
  @@dec_top : Painter::Bitmap? = nil
  class_property dec_top

  DEC_SIDE = "/hd0/share/wm/dec_side.png"
  @@dec_side : Painter::Bitmap? = nil
  class_property dec_side

  CLOSE = "/hd0/share/wm/close.png"
  @@close : Painter::Bitmap? = nil
  class_property close
end

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

  getter title

  def initialize(@x : Int32, @y : Int32,
                 width : Int32, height : Int32,
                 @title : String? = nil,
                 @alpha = false)
    @bitmap = Painter::Bitmap.new(width, height)
    if G::Sprites.dec_top.nil?
      G::Sprites.dec_top = Painter.load_png G::Sprites::DEC_TOP, @alpha
    end
    if G::Sprites.dec_side.nil?
      G::Sprites.dec_side = Painter.load_png G::Sprites::DEC_SIDE, @alpha
    end
    if G::Sprites.close.nil?
      G::Sprites.close = Painter.load_png G::Sprites::CLOSE, @alpha
    end
  end

  def self.new(window : G::Window, title : String? = nil)
    decoration = new 0, 0, window.width, window.height, title, window.flags.includes?(Wm::IPC::Data::WindowFlags::Alpha)
    window.main_widget = decoration
    decoration
  end

  TITLE_HEIGHT       = 20
  TITLE_PADDING_TOP  =  7
  TITLE_PADDING_SIDE =  3

  def calculate_main_dimensions
    x = TITLE_PADDING_SIDE
    y = TITLE_HEIGHT
    w = width - TITLE_PADDING_SIDE * 2
    h = height - y - 3
    {x, y, w, h}
  end

  BORDER   = 0x121517
  BG       = 0x1d1f21
  BORDER_A = 0xff000000 | BORDER
  BG_A     = 0xff000000 | BG

  @focused = true

  @close_x = 0
  @close_y = 0

  def draw_event
    Painter.blit_rect bitmap!, 0, 0, @alpha ? BG_A : BG

    # window decoration frame
    Painter.blit_img bitmap!,
      G::Sprites.dec_side.not_nil!,
      0, 0
    Painter.blit_img bitmap!,
      G::Sprites.dec_side.not_nil!,
      width - 1, 0
    (width - 2).times do |i|
      Painter.blit_img bitmap!,
        G::Sprites.dec_top.not_nil!,
        i + 1, 0
    end
    Painter.blit_rect bitmap!,
      1, height - 2,
      0, 1, @alpha ? BORDER_A : BORDER
    Painter.blit_rect bitmap!,
      1, height - 2,
      width - 1, 1, @alpha ? BORDER_A : BORDER

    # close button
    @close_x = width - G::Sprites.close.not_nil!.width - TITLE_PADDING_SIDE
    @close_y = 1
    Painter.blit_img bitmap!,
      G::Sprites.close.not_nil!,
      @close_x, @close_y

    # title
    if (title = @title)
      tx, ty = (width - G::Fonts.text_width(title)) // 2, TITLE_PADDING_TOP
      G::Fonts.blit self, tx, ty, title
    end

    # widget
    if (main_widget = @main_widget)
      main_widget.draw_event
      Painter.blit_img bitmap!,
        main_widget.bitmap!,
        main_widget.x, main_widget.y
    end
  end

  def io_event(io : IO::FileDescriptor)
    if main_widget = @main_widget
      main_widget.io_event io
    end
  end

  def key_event(ev : G::KeyboardEvent)
    if ev.modifiers.includes?(Wm::IPC::Data::KeyboardEventModifiers::GuiL)
      @last_mouse_x = -1
      @last_mouse_y = -1
      @win_key_pressed = true
      return
    else
      @win_key_pressed = false
    end
    if main_widget = @main_widget
      main_widget.key_event ev
    end
  end

  def wm_message_event(ev : Wm::IPC::Message)
    if ev.is_a?(Wm::IPC::Data::RefocusEvent)
      @last_mouse_x = -1
      @last_mouse_y = -1
      @focused = ev.focused > 0
      @app.not_nil!.redraw
    end
  end

  @last_mouse_x = -1
  @last_mouse_y = -1
  @win_key_pressed = false

  def mouse_event(ev : G::MouseEvent)
    if (main_widget = @main_widget) && !@win_key_pressed
      main_widget.mouse_event ev
      if main_widget.contains_point?(ev.relx, ev.rely)
        @last_mouse_x = -1
        @last_mouse_y = -1
        return
      end
    end
    if ev.modifiers.includes?(Wm::IPC::Data::MouseEventModifiers::LeftButton)
      close = G::Sprites.close.not_nil!
      if @close_x <= ev.relx <= (@close_x + close.width) &&
         @close_y <= ev.rely <= (@close_y + close.height)
        @app.not_nil!.close
      elsif @last_mouse_x != -1 && @last_mouse_y != -1
        delta_x = ev.x - @last_mouse_x
        delta_y = ev.y - @last_mouse_y
        if delta_x != 0 || delta_y != 0
          @app.not_nil!.move(delta_x, delta_y)
        end
      end
    end
    @last_mouse_x = ev.x
    @last_mouse_y = ev.y
  end
end
