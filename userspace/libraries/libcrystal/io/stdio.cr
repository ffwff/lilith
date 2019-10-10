class IO::FileDescriptor < IO

  def initialize(@fd : LibC::Int, blocking = false)
  end

  def read(slice : Bytes)
    LibC.read(@fd, slice.to_unsafe.as(LibC::String), slice.size)
  end

  def write(slice : Bytes)
    LibC.write(@fd, slice.to_unsafe.as(LibC::String), slice.size)
  end

end

STDIN  = IO::FileDescriptor.new 0
STDOUT = IO::FileDescriptor.new 1
STDERR = IO::FileDescriptor.new 2

def puts(*objects)
  STDOUT.puts objects
  nil
end