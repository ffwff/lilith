require "./async.cr"

PATH_MAX = 4096

abstract class VFSNode
  enum Buffering
    Unbuffered
    LineBuffered
    FullyBuffered
  end

  def size : Int
    0
  end
  def name : GcString?
  end

  abstract def fs : VFS

  def parent : VFSNode?
  end
  def next_node : VFSNode?
  end
  def first_child : VFSNode?
  end

  # used for internal file execution
  def read(&block)
  end

  def open(path : Slice) : VFSNode?
  end
  def create(name : Slice) : VFSNode?
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
    -1
  end

  def ioctl(request : Int32, data : UInt32) : Int32
    -1
  end
end

abstract class VFS
  abstract def name : GcString
  def queue : VFSQueue?
  end

  @next_node : VFS? = nil
  @prev_node : VFS? = nil
  property next_node, prev_node

  abstract def root : VFSNode
end

module RootFS
  extend self

  @@vfs_node : VFS? = nil

  def append(node : VFS)
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

  def remove(node : VFS)
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

VFS_ERR             = -1
VFS_WAIT            = -2
VFS_WAIT_NODE_QUEUE = -3
