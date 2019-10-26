class IPCSocket < IO::FileDescriptor
end

class IPCServer < IPCSocket

  def self.new(name)
    name.each_char do |char|
      return nil if char == '/'
    end
    filename = "/socket/" + name
    fd = LibC.create(filename.to_unsafe, open_mode)
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

end
