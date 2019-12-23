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
    header = uninitialized IPC::Data::Header
    if @socket.unbuffered_read(Bytes.new(pointerof(header).as(UInt8*),
         sizeof(IPC::Data::Header))) \
         != sizeof(IPC::Data::Header)
      return
    end
    case header.type
    when IPC::Data::WINDOW_CREATE_ID
      FixedMessageReader(IPC::Data::WindowCreate).read(header, @socket)
    when IPC::Data::RESPONSE_ID
      FixedMessageReader(IPC::Data::Response).read(header, @socket)
    when IPC::Data::KBD_EVENT_ID
      FixedMessageReader(IPC::Data::KeyboardEvent).read(header, @socket)
    when IPC::Data::MOUSE_EVENT_ID
      FixedMessageReader(IPC::Data::MouseEvent).read(header, @socket)
    when IPC::Data::MOVE_REQ_ID
      FixedMessageReader(IPC::Data::MoveRequest).read(header, @socket)
    when IPC::Data::REFOCUS_ID
      FixedMessageReader(IPC::Data::RefocusEvent).read(header, @socket)
    when IPC::Data::QUERY_ID
      FixedMessageReader(IPC::Data::Query).read(header, @socket)
    when IPC::Data::WINDOW_UPDATE_ID
      FixedMessageReader(IPC::Data::WindowUpdate).read(header, @socket)
    when IPC::Data::DYN_RESPONSE_ID
      payload = Bytes.new header.length
      return if socket.unbuffered_read(payload) != payload.size
      IPC::DynamicResponse.new payload
    else
      nil
    end
  end

  def create_window(x = 0, y = 0,
                    width = 400, height = 300,
                    flags = IPC::Data::WindowFlags::None)
    self << IPC.window_create_message(x, y, width, height, flags)
    IO::Select.wait @socket, timeout: (-1).to_u32
    response = read_message
    if response.is_a?(IPC::Data::Response)
      if response.retval != -1
        return Window.new(response.retval, self,
          x, y, width, height)
      end
    end
  end

  def screen_resolution : Tuple(Int32, Int32)?
    self << IPC.query_message(IPC::Data::QueryType::ScreenDim)
    IO::Select.wait @socket, timeout: (-1).to_u32
    response = read_message
    if response.is_a?(IPC::DynamicResponse)
      if response.buffer.size == 8
        ptr = response.buffer.to_unsafe.as(Int32*)
        return Tuple.new(ptr[0], ptr[1])
      end
    end
  end
end
