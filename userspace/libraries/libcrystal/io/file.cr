require "./stdio.cr"

class File < IO::FileDescriptor
  alias Result = ::Result(File, IO::Error)

  def self.new(filename : String, mode : String = "r") : Result
    open_mode = case mode
                when "r"
                  LibC::O_RDONLY
                when "w"
                  LibC::O_WRONLY | LibC::O_CREAT
                when "rw"
                  LibC::O_RDWR | LibC::O_CREAT
                else
                  return Result.new(IO::Error::InvalidArgument)
                end
    fd = LibC.open(filename.to_unsafe, open_mode)
    if fd >= 0
      Result.new(File.new(fd))
    else
      Result.new(IO::Error.new(fd))
    end
  end

  def self.open(filename : String, mode : String = "r", &block)
    if file = new(filename, mode).ok?
      retval = yield file
      file.close
      retval
    end
  end

  def truncate(length : LibC::Int)
    LibC.ftruncate @fd, length
  end

  def attributes
    LibC.fattr @fd
  end

  def self.remove(path : String)
    LibC.remove path
  end
end
