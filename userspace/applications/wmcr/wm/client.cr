require "socket"

class Wm::Client

  getter comm_pipe

  def initialize(@comm_pipe : IPCSocket)
  end

  def self.new
    if (comm_pipe = IPCSocket.new("wm")).nil?
      return nil
    end
    new comm_pipe
  end

  def <<(msg)
    @comm_pipe.unbuffered_write msg.to_slice
  end

  private struct FixedMessageReader(T)
    def self.read(header, socket)
      msg = uninitialized T
      msg.header = header
      payload = IPC.payload_bytes(msg)
      return if payload.size != header.length
      return if socket.unbuffered_read(payload) != payload.size
      msg
    end
  end

  def read_message : IPC::Message?
    header = uninitialized Wm::IPC::Data::Header
    if @comm_pipe.unbuffered_read(Bytes.new(pointerof(header).as(UInt8*),
                                            sizeof(Wm::IPC::Data::Header))) \
      != sizeof(Wm::IPC::Data::Header)
      return
    end
    case header.type
    when IPC::Data::WINDOW_CREATE_ID
      FixedMessageReader(Wm::IPC::Data::WindowCreate).read(header, @comm_pipe)
    when IPC::Data::RESPONSE_ID
      FixedMessageReader(Wm::IPC::Data::Response).read(header, @comm_pipe)
    else
      nil
    end
  end

  def create_window(x = 0, y = 0,
                    width = 400, height = 300)
    self << Wm::IPC.window_create_message(x, y, width, height)
    IO::Select.wait @comm_pipe, timeout: (-1).to_u32
    STDERR.puts "uhh1,.."
    response = read_message
    case response
    when Wm::IPC::Data::Response
      if response.retval == 1
        STDERR.puts "received!"
      end
    else
      nil
    end
  end

end
