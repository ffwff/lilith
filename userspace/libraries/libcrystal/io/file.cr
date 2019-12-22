require "./stdio.cr"

lib LibC

  O_RDONLY = 1 << 0
  O_WRONLY = 1 << 1
  O_RDWR   = O_RDONLY | O_WRONLY
  O_CREAT  = 1 << 2
  O_TRUNC  = 1 << 3
  O_APPEND = 1 << 4
  C_ANON   = 1 << 24

  @[Flags]
  enum FileAttributes : Int32
    Removed   = 1 << 0
    Anonymous = 1 << 1
    Directory = 1 << 2
  end

  fun remove(filename : LibC::UString) : LibC::Int
  fun open(filename : LibC::UString, mode : LibC::Int) : LibC::Int
  fun _open(filename : LibC::UString, mode : LibC::Int) : LibC::Int
  fun fattr(fd : LibC::Int) : FileAttributes
  fun create(filename : LibC::UString, mode : LibC::Int) : LibC::Int
  fun mmap(addr : Void*, size : LibC::SizeT, prot : LibC::Int,
           flags : LibC::Int, fd : LibC::Int, offset : LibC::OffT) : Void*
  fun munmap(addr : Void*)
  fun lseek(fd : LibC::Int, offset : Int32, whence : LibC::Int) : Int32
  fun _ioctl(fd : LibC::Int, request : LibC::Int, data : UInt64) : LibC::Int
  fun ftruncate(fd : LibC::Int, size : LibC::Int) : LibC::Int
end


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
