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

  abstract def open(path : Slice) : VFSNode?
  abstract def read(slice : Slice(UInt8), offset : UInt32,
                    process : Multiprocessing::Process? = nil) : Int32
  def read(&block)
    # for internal kernel reading
  end
  abstract def write(slice : Slice) : Int32
  def ioctl(request : Int32, data : Void*) : Int32
    -1
  end
end

abstract class VFS
  abstract def name : GcString
  def queue : VFSQueue?
  end

  abstract def next_node : VFS?
  abstract def next_node=(x : VFS?)

  abstract def root : VFSNode
end

class RootFS
  @vfs_node : VFS? = nil

  def initialize
  end

  def append(node : VFS)
    if @vfs_node.nil?
      node.next_node = nil
      @vfs_node = node
    else
      node.next_node = @vfs_node
      @vfs_node = node
    end
  end

  def each(&block)
    node = @vfs_node
    while !node.nil?
      yield node
      node = node.next_node
    end
  end
end

VFS_ERR       = -1
VFS_WAIT      = -2
