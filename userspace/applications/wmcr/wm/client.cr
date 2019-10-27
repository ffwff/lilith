require "socket"

class Wm::Client

  getter comm_pipe

  def initialize(@comm_pipe : IPCSocket)
    @comm_pipe.buffer_size = 0
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

end
