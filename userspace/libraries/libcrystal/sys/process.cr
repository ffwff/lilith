class Process
  enum Error
    FaultingAddress   = -2
    FileNotFound      = -3
    BadFileDescriptor = -4
    UnableToExecute   = -5
    InvalidArgument   =  0
  end

  alias Result = ::Result(Process, Error)

  private def initialize(@pid : LibC::Pid)
  end

  enum Redirect
    Pipe    = 0
    Close   = 1
    Inherit = 2
  end

  alias Stdio = IO::FileDescriptor | Process::Redirect

  def self.new(command : String, argv = nil,
               input : Stdio = Redirect::Close,
               output : Stdio = Redirect::Close,
               error : Stdio = Redirect::Close) : Result
    nargv = argv ? (1 + argv.size) : 1
    spawn_argv = Array(UInt8*).build(nargv + 1) do |buffer|
      buffer[0] = command.to_unsafe
      if argv
        i = 1
        argv.each do |arg|
          buffer[i] = arg.to_unsafe
          i += 1
        end
      end
      buffer[nargv] = Pointer(UInt8).null
      nargv + 1
    end
    startup_info = uninitialized LibC::StartupInfo
    startup_info.stdin = stdio_to_fd input, STDIN
    startup_info.stdout = stdio_to_fd output, STDOUT
    startup_info.stderr = stdio_to_fd error, STDERR
    pid = LibC.spawnxv(pointerof(startup_info),
      command.to_unsafe,
      spawn_argv.to_unsafe)
    if pid < 0
      Result.new(new(pid))
    else
      Result.new(Error.new(pid))
    end
  end

  private def self.stdio_to_fd(io : Stdio, default : IO::FileDescriptor)
    case io
    when IO::FileDescriptor
      io.fd
    when Redirect::Close
      -1
    when Redirect::Pipe
      default.fd
    when Redirect::Inherit
      default.fd
    else
      -1
    end
  end

  def wait
    LibC.waitpid @pid, Pointer(LibC::Int).null, 0
  end
end
