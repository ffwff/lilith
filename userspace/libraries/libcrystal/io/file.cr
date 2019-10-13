require "./stdio.cr"

lib LibC
  fun open(filename : LibC::UString, mode : LibC::UInt) : LibC::Int
end

O_RDONLY = 1 << 0
O_WRONLY = 1 << 1
O_RDWR   = O_RDONLY | O_WRONLY
O_CREAT  = 1 << 2
O_TRUNC  = 1 << 3
O_APPEND = 1 << 4

class File < IO::FileDescriptor
  def self.new(filename : String, mode : String = "r") : File?
    open_mode = case mode
                when "r"
                  O_RDONLY
                when "w"
                  O_WRONLY | O_CREAT
                else
                  return nil
                end
    fd = LibC.open(filename.to_unsafe, open_mode)
    if fd < 0
      nil
    else
      File.new fd
    end
  end
end
