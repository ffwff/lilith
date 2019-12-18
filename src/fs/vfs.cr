require "./async.cr"

PATH_MAX = 4096

module VFS
  extend self

  abstract class Node
    enum Buffering
      Unbuffered
      LineBuffered
      FullyBuffered
    end

    def size : Int
      0
    end

    def name : String?
    end

    abstract def fs : VFS

    def parent : Node?
    end

    def next_node : Node?
    end

    def first_child : Node?
    end

    # used for internal file execution
    def read(&block)
    end

    def open(path : Slice, process : Multiprocessing::Process? = nil) : Node?
    end

    def clone
    end

    def close
    end

    def create(name : Slice, process : Multiprocessing::Process? = nil, options : Int32 = 0) : Node?
    end

    def remove(process : Multiprocessing::Process? = nil) : Int32
      VFS_ERR
    end

    def read(slice : Slice(UInt8), offset : UInt32,
             process : Multiprocessing::Process? = nil) : Int32
      VFS_ERR
    end

    def write(slice : Slice(UInt8), offset : UInt32,
              process : Multiprocessing::Process? = nil) : Int32
      VFS_ERR
    end

    def spawn(udata : Multiprocessing::Process::UserData) : Int32
      VFS_ERR
    end

    def truncate(size : Int32) : Int32
      VFS_ERR
    end

    def ioctl(request : Int32, data : UInt64,
              process : Multiprocessing::Process? = nil) : Int32
      VFS_ERR
    end

    def mmap(node : MemMapNode, process : Multiprocessing::Process) : Int32
      VFS_ERR
    end

    def munmap(node : MemMapNode, process : Multiprocessing::Process) : Int32
      VFS_ERR
    end

    def available?(process : Multiprocessing::Process) : Bool
      true
    end

    def queue : Queue?
    end
  end

  abstract class FS
    abstract def name : String

    def queue : Queue?
    end

    @next_node : FS? = nil
    @prev_node : FS? = nil
    property next_node, prev_node

    abstract def root : Node
  end

end

module RootFS
  extend self

  @@vfs_node : VFS::FS? = nil

  def append(node : VFS::FS)
    if @@vfs_node.nil?
      node.next_node = nil
      node.prev_node = nil
      @@vfs_node = node
    else
      node.next_node = @@vfs_node
      @@vfs_node.not_nil!.prev_node = node
      @@vfs_node = node
    end
  end

  def remove(node : VFS::FS)
    unless node.next_node.nil?
      node.next_node.not_nil!.prev_node = node.prev_node
    end
    if node.prev_node.nil?
      @@vfs_node = node.next_node
    else
      node.prev_node.not_nil!.next_node = node.next_node
    end
  end

  def each(&block)
    node = @@vfs_node
    while !node.nil?
      yield node
      node = node.next_node
    end
  end
end

VFS_OK         =  0
VFS_ERR        = -1
VFS_WAIT       = -2
VFS_WAIT_QUEUE = -3
VFS_EOF        = -4

VFS_CREATE_ANON = 1 << 24
