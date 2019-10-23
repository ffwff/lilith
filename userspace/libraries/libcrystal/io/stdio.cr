require "./io.cr"
require "./buffered.cr"

lib LibC
  SEEK_SET = 0
  SEEK_CUR = 1
  SEEK_END = 2
end

class IO::FileDescriptor < IO
  include IO::Buffered

  getter fd

  def initialize(@fd : LibC::Int, blocking = false)
  end

  def unbuffered_read(slice : Bytes)
    LibC.read(@fd, slice.to_unsafe.as(LibC::String), slice.size)
  end

  def unbuffered_write(slice : Bytes)
    LibC.write(@fd, slice.to_unsafe.as(LibC::String), slice.size)
  end

  def map_to_memory(size = (-1).to_usize)
    LibC.mmap @fd, size
  end

  def size : Int
    cur = LibC.lseek @fd, 0, LibC::SEEK_CUR
    retval = LibC.lseek @fd, 0, LibC::SEEK_END
    LibC.lseek @fd, cur, LibC::SEEK_SET
    retval
  end
end

STDIN  = IO::FileDescriptor.new 0
STDOUT = IO::FileDescriptor.new 1
STDERR = IO::FileDescriptor.new 2
STDERR.buffer_size = 0

def puts(*objects)
  objects.each do |obj|
    STDOUT.puts obj
  end
  nil
end

def print(*objects)
  objects.each do |obj|
    STDOUT.print obj
  end
  nil
end
