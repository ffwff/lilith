require "./file.cr"

lib LibC
  alias Ino_t = LibC::Int

  struct Dirent
    # Inode number
    d_ino : Ino_t
    # Length of this record
    d_reclen : UInt16
    # Type of file; not supported by all filesystem types
    d_type : UInt8
    # Null-terminated filename
    d_name : UInt8[256]
  end

  fun lilith_readdir(fd : LibC::Int, direntp : Dirent*) : LibC::Int
end

class Dir
  def self.new(path)
    fd = LibC.open(path, O_RDONLY)
    if fd < 0
      nil
    else
      Dir.new fd
    end
  end

  def initialize(@fd : Int32)
  end

  def each_child(&block)
    dirent = uninitialized LibC::Dirent
    while LibC.lilith_readdir(@fd, pointerof(dirent)) > 0
      yield String.new(dirent.d_name.to_unsafe)
    end
    nil
  end
end
