class PipeFSRoot < VFSNode
  getter fs

  def initialize(@fs : PipeFS)
  end

  def open(path : Slice) : VFSNode?
    nil
  end

  def create(name : Slice) : VFSNode?
    each_child do |node|
      return if node.name == name
    end
    node = PipeFSNode.new(GcString.new(name), fs)
    node.next_node = @first_child
    @first_child = node
    node
  end

  def read(slice : Slice, offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    VFS_ERR
  end

  def write(slice : Slice, offset : UInt32,
            process : Multiprocessing::Process? = nil) : Int32
    VFS_ERR
  end

  @first_child : PipeFSNode? = nil
  getter first_child

  def each_child(&block)
    node = @first_child
    while !node.nil?
      yield node.not_nil!
      node = node.next_node
    end
  end
end

class PipeFSNode < VFSNode
  getter name, fs

  @next_node : PipeFSNode? = nil
  property next_node

  def initialize(@name : GcString, @fs : PipeFS)
  end

  def open(path : Slice) : VFSNode?
    nil
  end

  def create(name : Slice) : VFSNode?
    nil
  end

  def read(slice : Slice, offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    VFS_ERR
  end

  def write(slice : Slice, offset : UInt32,
            process : Multiprocessing::Process? = nil) : Int32
    VFS_ERR
  end
end

class PipeFS < VFS
  getter name, queue

  def initialize
    @name = GcString.new "pipes"
    @root = PipeFSRoot.new self
    @queue = VFSQueue.new
  end

  def root
    @root.not_nil!
  end

end
