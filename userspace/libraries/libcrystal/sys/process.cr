lib LibC
  fun spawnv(file : LibC::UString, argv : UInt8**) : LibC::Pid
  fun waitpid(pid : LibC::Pid, status : LibC::Int*, options : LibC::Int) : LibC::Pid
end

class Process

  private def initialize(@pid : LibC::Pid)
  end

  def self.new(command : String, argv = nil)
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
    pid = LibC.spawnv(command.to_unsafe,
                      spawn_argv.to_unsafe)
    if pid < 0
      nil
    else
      new pid
    end
  end

  def wait
    LibC.waitpid @pid, Pointer(LibC::Int).null, 0
  end

end
