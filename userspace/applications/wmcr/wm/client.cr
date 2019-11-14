require "socket"

class Wm::Client

  getter socket

  def initialize(@socket : IPCSocket)
  end

  def self.new
    if (socket = IPCSocket.new("wm")).nil?
      return nil
    end
    new socket
  end

  def <<(msg)
    @socket.unbuffered_write msg.to_slice
  end

  private struct FixedMessageReader(T)
    def self.read(header, socket)
      msg = uninitialized T
      msg.header = header
      payload = IPC.payload_bytes(msg)
      return if payload.size != header.length
      return if socket.unbuffered_read(payload) != payload.size
      return if !IPC.valid_msg?(Bytes.new(pointerof(msg).as(UInt8*), sizeof(T)))
      msg
    end
  end

  def read_message : IPC::Message?
    header = uninitialized Wm::IPC::Data::Header
    if @socket.unbuffered_read(Bytes.new(pointerof(header).as(UInt8*),
                                            sizeof(Wm::IPC::Data::Header))) \
      != sizeof(Wm::IPC::Data::Header)
      return
    end
    case header.type
    when IPC::Data::WINDOW_CREATE_ID
      FixedMessageReader(Wm::IPC::Data::WindowCreate).read(header, @socket)
    when IPC::Data::RESPONSE_ID
      FixedMessageReader(Wm::IPC::Data::Response).read(header, @socket)
    when IPC::Data::KBD_EVENT_ID
      FixedMessageReader(Wm::IPC::Data::KeyboardEvent).read(header, @socket)
    when IPC::Data::MOUSE_EVENT_ID
      FixedMessageReader(Wm::IPC::Data::MouseEvent).read(header, @socket)
    when IPC::Data::MOVE_REQ_ID
      FixedMessageReader(Wm::IPC::Data::MoveRequest).read(header, @socket)
    else
      nil
    end
  end

  def create_window(x = 0, y = 0,
                    width = 400, height = 300)
    self << Wm::IPC.window_create_message(x, y, width, height)
    IO::Select.wait @socket, timeout: (-1).to_u32
    response = read_message
    case response
    when Wm::IPC::Data::Response
      if response.retval != -1
        return Wm::Window.new(response.retval, self,
                              x, y, width, height)
      end
    end
  end

end
