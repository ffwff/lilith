class IO::Pipe < File

  SC_IOCTL_PIPE_CONF_FLAGS = 6
  SC_IOCTL_PIPE_CONF_PID   = 7

  @[Flags]
  enum Flags : UInt32
    WaitRead = 1 << 0
    M_Read   = 1 << 1
    S_Read   = 1 << 2
    M_Write  = 1 << 3
    S_Write  = 1 << 4
    G_Read   = 1 << 5
    G_Write  = 1 << 6
  end
  
  def self.new(name, mode, flags = Flags::None, pid : Int32? = nil)
    name.each_char do |char|
      return nil if char == '/'
    end
    if (file = new("/pipes/" + name, mode))
      if flags != Flags::None
        file.flags = flags
      end
      if !pid.nil?
        file.pid = pid.not_nil!
      end
      file
    end
  end

  def flags=(flag : Flags)
    LibC.ioctl(fd, SC_IOCTL_PIPE_CONF_FLAGS, flag.value)
  end

  def pid=(pid : Int32)
    LibC.ioctl(fd, SC_IOCTL_PIPE_CONF_PID, pid.to_u32)
  end

end
