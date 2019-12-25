require "./file.cr"

class Dir
  def self.new(path)
    fd = LibC.open(path, LibC::O_RDONLY)
    if fd < 0
      nil
    else
      Dir.new fd
    end
  end

  def self.open(path, &block)
    if dir = new path
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

  def self.current : String?
    unless dir = LibC.getcwd(nil, 0)
      # TODO: errno
      return nil
    end

    dir_str = String.new(dir)
    LibC.free(dir.as(Void*))
    dir_str
  end
end
