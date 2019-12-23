class IPCSocket < IO::FileDescriptor
  def initialize(@fd)
    self.buffer_size = 0
  end

  def self.new(name : String)
    filename = "/sockets/" + name + "/-"
    fd = LibC.create(filename.to_unsafe, LibC::O_RDWR)
    if fd >= 0
      new fd
    end
  end
end

class IPCServer < IPCSocket
  def self.new(name : String)
    name.each_char do |char|
      return nil if char == '/'
    end
    filename = "/sockets/" + name + "/listen"
    fd = LibC.create(filename, LibC::O_RDONLY)
    if fd >= 0
      new fd
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
