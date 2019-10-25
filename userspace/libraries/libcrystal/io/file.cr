require "./stdio.cr"

lib LibC

  O_RDONLY = 1 << 0
  O_WRONLY = 1 << 1
  O_RDWR   = O_RDONLY | O_WRONLY
  O_CREAT  = 1 << 2
  O_TRUNC  = 1 << 3
  O_APPEND = 1 << 4
  C_ANON   = 1 << 24

  fun open(filename : LibC::UString, mode : LibC::Int) : LibC::Int
  fun _open(filename : LibC::UString, mode : LibC::Int) : LibC::Int
  fun create(filename : LibC::UString, mode : LibC::Int) : LibC::Int
  fun mmap(fd : LibC::Int, size : LibC::SizeT) : Void*
  fun lseek(fd : LibC::Int, offset : Int32, whence : LibC::Int) : Int32
  fun _ioctl(fd : LibC::Int, request : LibC::Int, data : UInt32) : LibC::Int
end


class File < IO::FileDescriptor
  def self.new(filename : String, mode : String = "r") : File?
    open_mode = case mode
                when "r"
                  LibC::O_RDONLY
                when "w"
                  LibC::O_WRONLY | LibC::O_CREAT
                else
                  return nil
                end
    fd = LibC.open(filename.to_unsafe, open_mode)
    if fd >= 0
      File.new fd
    end
  end
end
