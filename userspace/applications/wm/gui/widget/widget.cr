struct G::KeyboardEvent
  getter ch

  def initialize(@ch : Char)
  end
end

struct G::MouseEvent
  getter x, y, modifiers, scroll_delta

  def initialize(@x : Int32, @y : Int32,
                 @modifiers : Wm::IPC::Data::MouseEventModifiers,
                 @scroll_delta : Int32)
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
  @width = 0
  @height = 0

  getter x : Int32, y : Int32
  getter width : Int32, height : Int32
  def move(@x : Int32, @y : Int32)
  end
  def resize(@width : Int32, @height : Int32)
  end

  def bitmap : UInt32*
    Pointer(UInt32).null
  end

  def contains_point?(x : Int, y : Int)
    @x <= x && x <= (@x + @width) &&
    @y <= y && y <= (@y + @height)
  end

  private macro def_event(name)
    def {{ name }}_event
    end
  end

  private macro def_event_d(name, type)
    def {{ name }}_event(data : {{ type }})
    end
  end

  def_event   setup
  def_event_d wm_message, Wm::IPC::Message
  def_event   draw
  def_event_d io, IO::FileDescriptor
  def_event_d key, KeyboardEvent
  def_event_d mouse, MouseEvent

end
