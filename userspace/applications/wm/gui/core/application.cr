class G::Application

  @client : Wm::Client
  getter client

  @main_widget : G::Widget? = nil
  getter main_widget

  def main_widget=(@main_widget : G::Widget)
    @main_widget.not_nil!.app = self
  end

  @running = true
  @selector_timeout : UInt64

  def initialize
    @client = Wm::Client.new.not_nil!
    @selector = IO::Select.new
    @selector << @client.socket

    @timers = [] of G::Timer
    @selector_timeout = (-1).to_u64
  end

  def watch_io(io : IO::FileDescriptor)
    @selector << io
  end

  def unwatch_io(io : IO::FileDescriptor)
    @selector.delete io
  end

  def register_timer(timer : G::Timer)
    @timers.push timer
    @selector_timeout = Math.min(@selector_timeout, timer.interval.to_u64 * 1000000)
  end

  def redraw
    if (main_widget = @main_widget)
      main_widget.draw_event
      send_redraw_message
    end
  end

  def send_redraw_message
    if (main_widget = @main_widget)
      @client << Wm::IPC.redraw_request_message(@x, @y, main_widget.width, main_widget.height)
    end
  end

  @x = 0
  @y = 0
  getter x, y
  def move(@x : Int32, @y : Int32)
    @client << Wm::IPC.move_request_message(@x, @y)
  end

  def run
    if (main_widget = @main_widget)
      main_widget.setup_event
      main_widget.draw_event
    end
    while @running
      io = @selector.wait @selector_timeout
      case io
      when @client.socket
        msg = @client.read_message
        if main_widget = @main_widget
          case msg
          when Wm::IPC::Data::WindowCreate
          when Wm::IPC::Data::Response
            # skip
          when Wm::IPC::Data::MouseEvent
            msg = msg.as Wm::IPC::Data::MouseEvent
            main_widget.mouse_event G::MouseEvent.new(msg.x, msg.y, msg.modifiers, msg.scroll_delta)
          when Wm::IPC::Data::KeyboardEvent
            msg = msg.as Wm::IPC::Data::KeyboardEvent
            main_widget.key_event G::KeyboardEvent.new(msg.ch.unsafe_chr)
          else
            if msg
              main_widget.wm_message_event msg
            end
          end
        end
      when IO::FileDescriptor
        if main_widget = @main_widget
          main_widget.io_event io
        end
      end
      if @timers.size > 0
        cur_time = Time.unix
        @timers.each do |timer|
          if cur_time - timer.last_tick >= timer.interval
            timer.on_tick
            timer.last_tick = cur_time
          end
        end
      end
    end
  end

end
