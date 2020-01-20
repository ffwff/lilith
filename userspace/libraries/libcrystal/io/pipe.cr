class IO::Pipe < IO::FileDescriptor
  alias Result = ::Result(IO::Pipe, IO::Error)

  private SC_IOCTL_PIPE_CONF_FLAGS = 6
  private SC_IOCTL_PIPE_CONF_PID   = 7

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

  def self.new(name, mode, flags = Flags::None, pid : Int32? = nil) : Result
    return Result.new(IO::Error::InvalidArgument) if name.includes?('/')
    open_mode = case mode
                when "r"
                  LibC::O_RDONLY
                when "w"
                  LibC::O_WRONLY
                when "rw"
                  LibC::O_RDONLY | LibC::O_WRONLY
                when "ra"
                  LibC::O_RDONLY | LibC::C_ANON
                when "wa"
                  LibC::O_WRONLY | LibC::C_ANON
                when "rwa"
                  LibC::O_RDONLY | LibC::O_WRONLY | LibC::C_ANON
                else
                  return Result.new(IO::Error::InvalidArgument)
                end
    filename = "/pipes/" + name
    fd = LibC.create(filename.to_unsafe, open_mode)
    if fd >= 0
      file = new fd
      if flags != Flags::None
        file.flags = flags
      else
        file.flags = Flags::G_Write | Flags::G_Read
      end
      if pid
        file.pid = pid
      end
      Result.new(file)
    else
      Result.new(IO::Error.new(fd))
    end
  end

  def self.exists?(name)
    return false if name.includes?('/')
    filename = "/pipes/" + name
    fd = LibC.open filename, LibC::O_RDONLY
    if fd < 0
      false
    else
      LibC.close fd
      true
    end
  end

  def flags=(flag : Flags)
    LibC._ioctl(fd, SC_IOCTL_PIPE_CONF_FLAGS, flag.value)
  end

  def pid=(pid : Int32)
    LibC._ioctl(fd, SC_IOCTL_PIPE_CONF_PID, pid.to_u32)
  end
end
