class Wm::Client

  @pipe_m : IO::Pipe? = nil
  @pipe_s : IO::Pipe? = nil
  getter comm_pipe, pipe_m, pipe_s

  def initialize(@comm_pipe : IO::Pipe)
  end

  def self.new
    if (comm_pipe = IO::Pipe.new("wm", "r")).nil?
      return nil
    end
    new comm_pipe
  end

end
