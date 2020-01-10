class IPCSocket < IO::FileDescriptor
  alias Result = ::Result(IPCSocket, IO::Error)
  
  def initialize(@fd)
    self.buffer_size = 0
  end

  def self.new(name : String) : Result
    filename = "/sockets/" + name + "/-"
    fd = LibC.create(filename.to_unsafe, LibC::O_RDWR)
    if fd >= 0
      Result.new(new(fd))
    else
      Result.new(IO::Error.new(fd))
    end
  end
end

class IPCServer < IPCSocket
  alias Result = ::Result(IPCServer, IO::Error)

  def self.new(name : String) : Result
    name.each_char do |char|
      return Result.new(IO::Error::InvalidArgument) if char == '/'
    end
    filename = "/sockets/" + name + "/listen"
    fd = LibC.create(filename, LibC::O_RDONLY)
    if fd >= 0
      Result.new(new(fd))
    else
      Result.new(IO::Error.new(fd))
    end
  end

  def accept?
    fd : Int32 = 0
    if unbuffered_read(Bytes.new(pointerof(fd).as(UInt8*), sizeof(Int32))) <= 0
      return nil
    end
    if fd >= 0
      IPCSocket.new fd
    end
  end

  def self.remove(name : String)
    filename = "/sockets/" + name + "/-"
    LibC.remove(filename)
  end
end
