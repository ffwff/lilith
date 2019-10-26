private class SocketFSRoot < VFSNode
  getter fs : VFS

  def initialize(@fs : SocketFS)
  end

  def open(path : Slice) : VFSNode?
    each_child do |node|
      return node if node.name == path
    end
  end

  def create(name : Slice, process : Multiprocessing::Process? = nil) : VFSNode?
    node = SocketFSNode.new(String.new(name), self, fs)
    node.next_node = @first_child
    unless @first_child.nil?
      @first_child.not_nil!.prev_node = node
    end
    @first_child = node
    node
  end

  def remove(node : SocketFSNode)
    if node == @first_child
      @first_child = node.next_node
    end
    unless node.prev_node.nil?
      node.prev_node.not_nil!.next_node = node.next_node
    end
    unless node.next_node.nil?
      node.next_node.not_nil!.prev_node = node.prev_node
    end
  end

  @first_child : SocketFSNode? = nil
  getter first_child

  def each_child(&block)
    node = @first_child
    while !node.nil?
      yield node.not_nil!
      node = node.next_node
    end
  end
end

private class SocketFSNode < VFSNode
  getter! name : String
  getter fs : VFS

  @next_node : SocketFSNode? = nil
  property next_node

  @prev_node : SocketFSNode? = nil
  property prev_node

  def initialize(@name : String, @parent : SocketFSRoot, @fs : SocketFS)
  end

  def remove : Int32
    0
  end

  def read(slice : Slice, offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    0
  end

  def write(slice : Slice, offset : UInt32,
            process : Multiprocessing::Process? = nil) : Int32
    0
  end

  def available?
    false
  end
end

private class SocketFSListenNode < VFSNode
  getter! name : String
  getter fs : VFS

  @next_node : SocketFSNode? = nil
  property next_node

  @prev_node : SocketFSNode? = nil
  property prev_node

  def initialize(@name : String, @parent : SocketFSRoot, @fs : SocketFS)
  end

  def remove : Int32
    0
  end

  def read(slice : Slice, offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    0
  end

  def write(slice : Slice, offset : UInt32,
            process : Multiprocessing::Process? = nil) : Int32
    0
  end

  def available?
    false
  end
end

private class SocketFSConnectionNode < VFSNode
  getter fs : VFS

  def initialize(@parent : SocketFSNode, @fs : SocketFS)
  end

  def remove : Int32
    0
  end

  def read(slice : Slice, offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    0
  end

  def write(slice : Slice, offset : UInt32,
            process : Multiprocessing::Process? = nil) : Int32
    0
  end

  def available?
    false
  end
end

class SocketFS < VFS
  getter! root : VFSNode

  def name
    "socket"
  end

  def initialize
    @root = SocketFSRoot.new self
  end
end

