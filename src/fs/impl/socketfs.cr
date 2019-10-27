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
  getter fs : VFS, queue : VFSQueue
  property listener_pid

  def initialize(@parent : SocketFSNode, @fs : SocketFS)
    @listener_pid = -1
    @queue = VFSQueue.new
  end

  def name
    "listen"
  end

  def try_connect(conn)
    @queue.enqueue VFSMessage.new(nil, conn, nil)
  end

  def read(slice : Slice, offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    return VFS_ERR if process.not_nil!.pid != @listener_pid
    return 0 if slice.size != sizeof(Int32)
    if (msg = @queue.dequeue)
      conn = msg.vfs_node.unsafe_as(SocketFSConnectionNode)
      conn.state = SocketFSConnectionNode::State::Connected
      conn.flush_queue
      fd = process.not_nil!.udata.install_fd(conn,
                                             FileDescriptor::Attributes::Read |
                                             FileDescriptor::Attributes::Write)
      slice.to_unsafe.as(Int32*).value = fd
      slice.size
    else
      0
    end
  end

  def available?(process : Multiprocessing::Process) : Bool
    # TODO
    true
  end
end

class SocketFSConnectionNode < VFSNode
  getter fs : VFS, queue : VFSQueue
  property connected

  enum State
    Disconnected
    TryConnect
    Connected
  end
  @state = State::Disconnected
  property state

  def initialize(@parent : SocketFSNode, @fs : SocketFS)
    @queue = VFSQueue.new
    @m_buffer = CircularBuffer.new
    @s_buffer = CircularBuffer.new
    @open_count = 1
  end

  def clone
    @open_count += 1
  end

  def close
    @open_count -= 1
    if @open_count == 0
      @m_buffer.deinit_buffer
      @s_buffer.deinit_buffer
      @connected = false
    end
  end

  def read(slice : Slice, offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    Serial.puts "read: ", @state, "!\n"
    case @state
    when State::Disconnected
      @parent.listen_node.try_connect(self)
      @state = State::TryConnect
      return 0
    when State::TryConnect
      return 0
    end
    if process.not_nil!.pid == @parent.listen_node.listener_pid
      @s_buffer.read slice
    else
      Serial.puts "client read\n"
      @m_buffer.read slice
    end
  end

  def write(slice : Slice, offset : UInt32,
            process : Multiprocessing::Process? = nil) : Int32
    case @state
    when State::Disconnected
      @parent.listen_node.try_connect(self)
      return VFS_WAIT_QUEUE
    when State::TryConnect
      return VFS_WAIT_QUEUE
    end
    if process.not_nil!.pid == @parent.listen_node.listener_pid
      Serial.puts "listener write\n"
      @m_buffer.write slice
    else
      @s_buffer.write slice
    end
  end

  def flush_queue
    @queue.keep_if do |msg|
      Serial.puts "msg: ", msg.type, '\n'
      case msg.type
      when VFSMessage::Type::Write
        @s_buffer.init_buffer
        msg.read do |ch|
          @s_buffer.write ch
        end
        msg.unawait msg.slice_size
      end
      false
    end
  end

  def available?(process : Multiprocessing::Process) : Bool
    Serial.puts "wait...\n"
    case @state
    when State::Disconnected
      @parent.listen_node.try_connect(self)
      @state = State::TryConnect
      return false
    when State::TryConnect
      return false
    end
    if process.pid == @parent.listen_node.listener_pid
      @s_buffer.size > 0
    else
      @m_buffer.size > 0
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

