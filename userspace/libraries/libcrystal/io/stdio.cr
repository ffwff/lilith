require "./io.cr"
require "./buffered.cr"

class IO::FileDescriptor < IO
  include IO::Buffered

  getter fd

  def initialize(@fd : LibC::Int, blocking = false)
  end

  def close
    LibC.close @fd
  end

  def unbuffered_read(slice : Bytes)
    LibC.read(@fd, slice.to_unsafe.as(LibC::String), slice.size)
  end

  def unbuffered_write(slice : Bytes)
    LibC.write(@fd, slice.to_unsafe.as(LibC::String), slice.size)
  end

  def map_to_memory(address : UInt8* = Pointer(UInt8).null,
                    size : LibC::SizeT = (-1).to_usize,
                    prot : LibC::MmapProt = LibC::MmapProt::None,
                    flags : Int = 0,
                    offset : LibC::OffT = 0)
    LibC.mmap address, size, prot.value, flags, @fd, offset
  end

  def rewind
    LibC.lseek @fd, 0, LibC::SEEK_SET
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
