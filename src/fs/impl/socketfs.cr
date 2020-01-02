require "./pipe/circular_buffer.cr"

class SocketFS::Root < VFS::Node
  getter fs : VFS::FS

  def initialize(@fs : SocketFS::FS)
  end

  def open(path : Slice, process : Multiprocessing::Process? = nil) : VFS::Node?
    each_child do |node|
      return node if node.name == path
    end
  end

  def create(name : Slice, process : Multiprocessing::Process? = nil, options : Int32 = 0) : VFS::Node?
    node = SocketFS::Node.new(String.new(name), self, fs)
    node.next_node = @first_child
    unless @first_child.nil?
      @first_child.not_nil!.prev_node = node
    end
    @first_child = node
    node
  end

  def remove(node : SocketFS::Node)
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

  @first_child : SocketFS::Node? = nil
  getter first_child

  def each_child(&block)
    node = @first_child
    while !node.nil?
      yield node.not_nil!
      node = node.next_node
    end
  end
end

class SocketFS::Node < VFS::Node
  getter! name : String, listen_node
  getter fs : VFS::FS

  def first_child
    @listen_node
  end

  @next_node : SocketFS::Node? = nil
  property next_node

  @prev_node : SocketFS::Node? = nil
  property prev_node

  def initialize(@name : String, @parent : SocketFS::Root, @fs : SocketFS::FS)
    @listen_node = SocketFS::ListenNode.new self, @fs
  end

  def open(path : Slice, process : Multiprocessing::Process? = nil)
    if path == @listen_node.not_nil!.name
      @listen_node.not_nil!.listener_pid = process.not_nil!.pid
      @listen_node
    else
      SocketFS::ConnectionNode.new(self, @fs)
    end
  end
end

class SocketFS::ListenNode < VFS::Node
  getter fs : VFS::FS, queue : VFS::Queue
  property listener_pid

  def initialize(@parent : SocketFS::Node, @fs : SocketFS::FS)
    @listener_pid = -1
    @queue = VFS::Queue.new
  end

  def name
    "listen"
  end

  def try_connect(conn)
    @queue.enqueue VFS::Message.new(nil, conn, nil)
  end

  def read(slice : Slice, offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    return VFS_ERR if process.not_nil!.pid != @listener_pid
    return 0 if slice.size != sizeof(Int32)
    if (msg = @queue.dequeue)
      conn = msg.vfs_node.as!(SocketFS::ConnectionNode)
      conn.state = SocketFS::ConnectionNode::State::Connected
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
    !@queue.empty?
  end
end

class SocketFS::ConnectionNode < VFS::Node
  getter fs : VFS::FS, queue : VFS::Queue
  property connected

  enum State
    Disconnected
    TryConnect
    Connected
    DisconnectedForever
  end
  @state = State::Disconnected
  property state

  def initialize(@parent : SocketFS::Node, @fs : SocketFS::FS)
    @queue = VFS::Queue.new
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
      @state = State::DisconnectedForever
    end
  end

  def read(slice : Slice, offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    case @state
    when State::Disconnected
      @parent.listen_node.try_connect(self)
      @state = State::TryConnect
      return 0
    when State::TryConnect
      return 0
    when State::DisconnectedForever
      return 0
    end
    if process.not_nil!.pid == @parent.listen_node.listener_pid
      @s_buffer.read slice
    else
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
    when State::DisconnectedForever
      return 0
    end
    if process.not_nil!.pid == @parent.listen_node.listener_pid
      @m_buffer.write slice
    else
      @s_buffer.write slice
    end
  end

  def flush_queue
    @queue.keep_if do |msg|
      case msg.type
      when VFS::Message::Type::Write
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
    case @state
    when State::Disconnected
      @parent.listen_node.try_connect(self)
      @state = State::TryConnect
      return false
    when State::TryConnect
      return false
    when State::DisconnectedForever
      return true
    end
    if process.pid == @parent.listen_node.listener_pid
      @s_buffer.size > 0
    else
      @m_buffer.size > 0
    end
  end
end

class SocketFS::FS < VFS::FS
  getter! root : VFS::Node

  def name : String
    "sockets"
  end

  def initialize
    @root = SocketFS::Root.new self
  end
end
