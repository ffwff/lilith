require "./async.cr"

PATH_MAX = 4096

abstract class VFSNode < Gc
  abstract def size : Int
  abstract def name : GcString?

  abstract def parent : VFSNode?
  abstract def next_node : VFSNode?
  abstract def first_child : VFSNode?

  abstract def open(path : Slice) : VFSNode?
  abstract def read(slice : Slice(UInt8), offset : UInt32,
                    process : Multiprocessing::Process? = nil) : Int32
  abstract def write(slice : Slice) : Int32

  abstract def read_queue : VFSReadQueue?
end

abstract class VFS < Gc
  abstract def name : GcString

  abstract def next_node : VFS?
  abstract def next_node=(x : VFS?)

  abstract def root : VFSNode
end

class RootFS < Gc
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
VFS_READ_WAIT = -2
