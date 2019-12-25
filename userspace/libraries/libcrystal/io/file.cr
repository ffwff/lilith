require "./stdio.cr"

class File < IO::FileDescriptor
  def self.new(filename : String, mode : String = "r") : File?
    open_mode = case mode
                when "r"
                  LibC::O_RDONLY
                when "w"
                  LibC::O_WRONLY | LibC::O_CREAT
                when "rw"
                  LibC::O_RDWR | LibC::O_CREAT
                else
                  return nil
                end
    fd = LibC.open(filename.to_unsafe, open_mode)
    if fd >= 0
      File.new fd
    end
  end

  def self.open(filename : String, mode : String = "r", &block)
    if file = File.new filename, mode
      yield file
      file.close
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
