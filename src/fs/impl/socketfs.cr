require "./pipe/circular_buffer.cr"

module SocketFS
  extend self
  class Node < VFS::Node
    include VFS::Child(Node)

    getter! name : String, listen_node
    getter fs : VFS::FS

    def initialize(@name : String, @parent : Root, @fs : FS)
      @listen_node = ListenNode.new self, @fs
    end

    def open(path : Slice, process : Multiprocessing::Process? = nil)
      if path == @listen_node.not_nil!.name
        @listen_node.not_nil!.listener_pid = process.not_nil!.pid
        @listen_node
      else
        ConnectionNode.new(self, @fs)
      end
    end
  end

  class Root < VFS::Node
    include VFS::Enumerable(Node)
    getter fs : VFS::FS

    def initialize(@fs : FS)
      @attributes |= VFS::Node::Attributes::Directory
    end

    def create(name : Slice, process : Multiprocessing::Process? = nil, options : Int32 = 0) : VFS::Node?
      node = Node.new(String.new(name), self, fs)
      add_child node
      node
    end
  end

  class ListenNode < VFS::Node
    getter fs : VFS::FS, queue : VFS::Queue
    property listener_pid

    def initialize(@parent : Node, @fs : FS)
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
        conn = msg.vfs_node.as!(ConnectionNode)
        conn.state = ConnectionNode::State::Connected
        conn.flush_queue
        conn.clone
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

  class ConnectionNode < VFS::Node
    getter fs : VFS::FS, queue : VFS::Queue
    property connected

    enum State
      Disconnected
      TryConnect
      Connected
      DisconnectedForever
    end
    property state

    def initialize(@parent : Node, @fs : FS)
      @state = State::Disconnected
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
        return VFS_EOF
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
        return VFS_EOF
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

  class FS < VFS::FS
    getter! root : VFS::Node

    def name : String
      "sockets"
    end

    def initialize
      @root = Root.new self
    end
  end

end
