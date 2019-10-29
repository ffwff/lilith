class G::Application

  @client : Wm::Client
  getter client

  @main_widget : G::Widget? = nil
  getter main_widget

  def main_widget=(@main_widget : G::Widget)
    @main_widget.not_nil!.app = self
  end

  @running = true

  def initialize
    @client = Wm::Client.new.not_nil!
    @selector = IO::Select.new
    @selector << @client.socket
  end

  def run
    if (main_widget = @main_widget)
      main_widget.setup_event
    end
    while @running
      io = @selector.wait
      case io
      when @client.socket
        msg = @client.read_message
        if !(main_widget = @main_widget).nil?
          case msg
          when Wm::IPC::Data::WindowCreate
          when Wm::IPC::Data::Response
            # skip
          else
            if msg
              main_widget.wm_message_event msg
            end
          end
        end
      end
    end
  end

end
