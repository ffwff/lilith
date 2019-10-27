require "./pipe/circular_buffer.cr"

private class PipeFSRoot < VFSNode
  getter fs : VFS

  def initialize(@fs : PipeFS)
  end

  def open(path : Slice, process : Multiprocessing::Process? = nil) : VFSNode?
    each_child do |node|
      return node if node.name == path
    end
  end

  def create(name : Slice,
             process : Multiprocessing::Process? = nil,
             options : Int32 = 0) : VFSNode?
    if (options & VFS_CREATE_ANON) != 0
      return PipeFSNode.new(String.new(name),
                            process.not_nil!.pid,
                            self, fs,
                            anonymous: true)
    end
    node = PipeFSNode.new(String.new(name),
                          process.not_nil!.pid,
                          self, fs)
    node.next_node = @first_child
    unless @first_child.nil?
      @first_child.not_nil!.prev_node = node
    end
    @first_child = node
    node
  end

  def remove(node : PipeFSNode)
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

private class PipeFSNode < VFSNode
  getter! name : String
  getter fs : VFS

  @next_node : PipeFSNode? = nil
  property next_node

  @prev_node : PipeFSNode? = nil
  property prev_node

  def initialize(@name : String,
                 @m_pid,
                 @parent : PipeFSRoot,
                 @fs : PipeFS,
                 anonymous = false)
    if anonymous
      @open_count += 1
      @flags |= Flags::Anonymous
    end
    @pipe = CircularBuffer.new
    # Serial.puts "mk ", @name, '\n'
  end

  def close
    if @flags.includes?(Flags::Anonymous)
      @open_count -= 1
      remove if @open_count == 0
    end
  end

  def clone
    @open_count += 1
  end

  @[Flags]
  enum Flags : UInt32
    WaitRead  = 1 << 0
    M_Read    = 1 << 1
    S_Read    = 1 << 2
    M_Write   = 1 << 3
    S_Write   = 1 << 4
    G_Read    = 1 << 5
    G_Write   = 1 << 6
    Removed   = 1 << 30
    Anonymous = 1 << 31
  end

  @flags = Flags::None
  @m_pid = 0
  @s_pid = 0
  @open_count = 0

  def size : Int
    @pipe.size
  end

  def remove : Int32
    return VFS_ERR if @flags.includes?(Flags::Removed)
    @parent.remove self unless @flags.includes?(Flags::Anonymous)
    @pipe.deinit_buffer
    @flags |= Flags::Removed
    VFS_OK
  end

  def read(slice : Slice, offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    return VFS_EOF if @flags.includes?(Flags::Removed)

    process = process.not_nil!
    # Serial.puts "rd from ", process.pid, "(", @m_pid, ",", @s_pid, ")", "\n"
    unless @flags.includes?(Flags::G_Read)
      if process.pid == @m_pid
        return 0 unless @flags.includes?(Flags::M_Read)
      elsif process.pid == @s_pid
        return 0 unless @flags.includes?(Flags::S_Read)
      else
        return 0
      end
    end

    @pipe.read slice
  end

  def write(slice : Slice, offset : UInt32,
            process : Multiprocessing::Process? = nil) : Int32
    return VFS_EOF if @flags.includes?(Flags::Removed)

    process = process.not_nil!
    # Serial.puts "wr from ", process.pid, "(", @m_pid, ",", @s_pid, ")", "\n"
    unless @flags.includes?(Flags::G_Write)
      if process.pid == @m_pid
        return 0 unless @flags.includes?(Flags::M_Write)
      elsif process.pid == @s_pid
        return 0 unless @flags.includes?(Flags::S_Write)
      else
        return 0
      end
    end

    @pipe.write slice
  end

  def available?(process : Multiprocessing::Process) : Bool
    return true if @flags.includes?(Flags::Removed)
    size > 0
  end

  def ioctl(request : Int32, data : UInt32,
            process : Multiprocessing::Process? = nil) : Int32
    return -1 unless process.not_nil!.pid == @m_pid
    return -1 if @flags.includes?(Flags::Removed)
    case request
    when SC_IOCTL_PIPE_CONF_FLAGS
      # 24-bits for options! (last 8-bits are reserved for node state)
      data = data & 0xffffff
      @flags = Flags.new(data)
      0
    when SC_IOCTL_PIPE_CONF_PID
      @s_pid = data.to_i32
    else
      -1
    end
  end
end

class PipeFS < VFS
  getter! root : VFSNode

  def name
    "pipes"
  end

  def initialize
    @root = PipeFSRoot.new self
  end
end
