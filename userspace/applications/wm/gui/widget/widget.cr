struct G::KeyboardEvent
  getter ch, modifiers

  def initialize(@ch : Char,
                 @modifiers : Wm::IPC::Data::KeyboardEventModifiers)
  end
end

struct G::MouseEvent
  getter x, y, relx, rely, modifiers, scroll_delta

  def initialize(@x : Int32, @y : Int32,
                 @modifiers : Wm::IPC::Data::MouseEventModifiers,
                 @scroll_delta : Int32,
                 @relx : Int32, @rely : Int32)
  end

  def left_clicked?
    @modifiers.includes? Wm::IPC::Data::MouseEventModifiers::LeftButton
  end

  def right_clicked?
    @modifiers.includes? Wm::IPC::Data::MouseEventModifiers::RightButton
  end
end

abstract class G::Widget
  @app : G::Application? = nil
  getter! app
  setter app

  @x = 0
  @y = 0
  getter x : Int32, y : Int32

  @bitmap : Painter::Bitmap? = nil
  getter bitmap

  def bitmap!
    @bitmap.not_nil!
  end

  def width
    if bitmap = @bitmap
      bitmap.width
    else
      0
    end
  end

  def height
    if bitmap = @bitmap
      bitmap.height
    else
      0
    end
  end

  def move(@x : Int32, @y : Int32)
  end

  def resize(width : Int32, height : Int32)
    if bitmap = @bitmap
      bitmap.resize width, height
    end
  end

  def contains_point?(x : Int, y : Int)
    if bitmap = @bitmap
      @x <= x <= (@x + bitmap.width) &&
        @y <= y <= (@y + bitmap.height)
    else
      false
    end
  end

  private macro def_event(name)
    def {{ name }}_event
    end
  end

  private macro def_event_d(name, type)
    def {{ name }}_event(data : {{ type }})
    end
  end

  def_event setup
  def_event_d wm_message, Wm::IPC::Message
  def_event draw
  def_event_d io, IO::FileDescriptor
  def_event_d key, KeyboardEvent
  def_event_d mouse, MouseEvent
end
