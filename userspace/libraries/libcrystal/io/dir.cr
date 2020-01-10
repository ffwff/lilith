require "./file.cr"

class Dir
  alias Result = ::Result(Dir, IO::Error)

  def self.new(path) : Result
    fd = LibC.open(path, LibC::O_RDONLY)
    if fd >= 0
      Result.new(Dir.new(fd))
    else
      Result.new(IO::Error.new(fd))
    end
  end

  def self.open(path, &block)
    if dir = new(path).ok?
      yield dir
      dir.close
    end
  end

  def initialize(@fd : Int32)
  end

  def close
    LibC.close @fd
    @fd = -1
  end

  def each_child(&block)
    dirent = uninitialized LibC::Dirent
    while LibC.lilith_readdir(@fd, pointerof(dirent)) > 0
      yield String.new(dirent.d_name.to_unsafe)
    end
    nil
  end

  def self.cd(path)
    LibC.chdir path.to_unsafe
  end

  def self.current : ::Result(String, IO::Error)
    unless dir = LibC.getcwd(nil, 0)
      # FIXME: errno
      return ::Result(String, IO::Error).new(IO::Error::InvalidArgument)
    end

    dir_str = String.new(dir)
    LibC.free(dir.as(Void*))
    ::Result(String, IO::Error).new(dir_str)
  end
end
