private class PipeFSRoot < VFSNode
  getter fs : VFS

  def initialize(@fs : PipeFS)
  end

  def open(path : Slice) : VFSNode?
    each_child do |node|
      return node if node.name == path
    end
  end

  def create(name : Slice, process : Multiprocessing::Process? = nil) : VFSNode?
    each_child do |node|
      return if node.name == name
    end
    node = PipeFSNode.new(String.new(name), process.not_nil!.pid, self, fs)
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

  def initialize(@name : String, @m_pid, @parent : PipeFSRoot, @fs : PipeFS)
    # Serial.puts "mk ", @name, '\n'
  end

  @buffer = Pointer(UInt8).null
  @read_pos = 0
  @write_pos = 0
  BUFFER_CAPACITY = 0x1000

  @[Flags]
  enum Flags : UInt32
    WaitRead = 1 << 0
    M_Read   = 1 << 1
    S_Read   = 1 << 2
    M_Write  = 1 << 3
    S_Write  = 1 << 4
    G_Read   = 1 << 5
    G_Write  = 1 << 6
    Removed  = 1 << 7
  end

  @flags = Flags::None
  @m_pid = 0
  @s_pid = 0

  def size : Int
    @write_pos - @read_pos
  end

  def remove : Int32
    return VFS_ERR if @flags.includes?(Flags::Removed)
    FrameAllocator.declaim_addr(@buffer.address & ~PTR_IDENTITY_MASK)
    @buffer = Pointer(UInt8).null
    @parent.remove self
    @flags |= Flags::Removed
    VFS_OK
  end

  private def init_buffer
    if @buffer.null?
      @buffer = Pointer(UInt8).new(FrameAllocator.claim_with_addr | PTR_IDENTITY_MASK)
    end
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

    init_buffer

    slice.size.times do |i|
      slice.to_unsafe[i] = @buffer[@read_pos]
      @read_pos += 1
      if @read_pos == BUFFER_CAPACITY - 1
        @read_pos = 0
      end
      return i if @read_pos == @write_pos
    end

    slice.size
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

    init_buffer

    slice.size.times do |i|
      @buffer[@write_pos] = slice.to_unsafe[i]
      @write_pos += 1
      if @write_pos == BUFFER_CAPACITY - 1
        @write_pos = 0
      end
      return i if @read_pos == @write_pos
    end

    slice.size
  end

  def available?
    return true if @flags.includes?(Flags::Removed)
    size > 0
  end

  def ioctl(request : Int32, data : UInt32,
            process : Multiprocessing::Process? = nil) : Int32
    return -1 unless process.not_nil!.pid == @m_pid
    return -1 if @flags.includes?(Flags::Removed)
    case request
    when SC_IOCTL_PIPE_CONF_FLAGS
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
