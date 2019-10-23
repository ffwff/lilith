class Wm::Client

  getter comm_pipe

  def initialize(@comm_pipe : IO::Pipe)
    @comm_pipe.buffer_size = 0
  end

  def self.new
    if (comm_pipe = IO::Pipe.new("wm", "w")).nil?
      return nil
    end
    new comm_pipe
  end

  def <<(msg)
    @comm_pipe.unbuffered_write msg.to_slice
  end

end
