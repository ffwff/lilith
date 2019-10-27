require "./pipe/circular_buffer.cr"

private class SocketFSRoot < VFSNode
  getter fs : VFS

  def initialize(@fs : SocketFS)
  end

  def open(path : Slice, process : Multiprocessing::Process? = nil) : VFSNode?
    each_child do |node|
      return node if node.name == path
    end
  end

  def create(name : Slice, process : Multiprocessing::Process? = nil, options : Int32 = 0) : VFSNode?
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
  getter! name : String, listen_node
  getter fs : VFS

  def first_child
    @listen_node
  end

  @next_node : SocketFSNode? = nil
  property next_node

  @prev_node : SocketFSNode? = nil
  property prev_node

  def initialize(@name : String, @parent : SocketFSRoot, @fs : SocketFS)
    @listen_node = SocketFSListenNode.new self, @fs
  end

  def open(path : Slice, process : Multiprocessing::Process? = nil)
    if path == @listen_node.not_nil!.name
      @listen_node.not_nil!.listener_pid = process.not_nil!.pid
      @listen_node
    else
      SocketFSConnectionNode.new(self, @fs)
    end
  end

end

private class SocketFSListenNode < VFSNode
  getter fs : VFS
  property listener_pid

  def initialize(@parent : SocketFSNode, @fs : SocketFS)
    @listener_pid = -1
  end

  def name
    "listen"
  end

  @queued_connection : SocketFSConnectionNode? = nil

  def try_connect(conn)
    if @queued_connection.nil?
      @queued_connection = conn
    end
  end

  def read(slice : Slice, offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    return VFS_ERR if process.not_nil!.pid != @listener_pid
    return 0 if slice.size != sizeof(Int32)
    if (conn = @queued_connection)
      conn.connected = true
      fd = process.not_nil!.udata.install_fd(conn,
                                             FileDescriptor::Attributes::Read |
                                             FileDescriptor::Attributes::Write)
      slice.to_unsafe.as(Int32*).value = fd
      slice.size
    else
      VFS_WAIT_POLL
    end
  end

  def available?(process : Multiprocessing::Process) : Bool
    !@queued_connection.nil?
  end
end

private class SocketFSConnectionNode < VFSNode
  getter fs : VFS
  property connected

  def initialize(@parent : SocketFSNode, @fs : SocketFS)
    @m_buffer = CircularBuffer.new
    @s_buffer = CircularBuffer.new
    @connected = false
  end

  def remove : Int32
    0
  end

  def read(slice : Slice, offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    if !available?(process.not_nil!)
      return VFS_WAIT_POLL
    end
    if process.not_nil!.pid == @parent.listen_node.listener_pid
      @s_buffer.read slice
    else
      @m_buffer.read slice
    end
  end

  def write(slice : Slice, offset : UInt32,
            process : Multiprocessing::Process? = nil) : Int32
    if !available?(process.not_nil!)
      return VFS_WAIT_POLL
    end
    if process.not_nil!.pid == @parent.listen_node.listener_pid
      @m_buffer.write slice
    else
      @s_buffer.write slice
    end
  end

  def available?(process : Multiprocessing::Process) : Bool
    if !@connected
      @parent.listen_node.try_connect(self)
      return false
    end
    if process.pid == @parent.listen_node.listener_pid
      @s_buffer.size > 0
    else # TODO
      true
      # @m_buffer.size > 0
    end
  end
end

class SocketFS < VFS
  getter! root : VFSNode

  def name
    "sockets"
  end

  def initialize
    @root = SocketFSRoot.new self
  end
end

