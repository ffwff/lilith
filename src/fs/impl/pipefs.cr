private class PipeFSRoot < VFSNode
  getter fs

  def initialize(@fs : PipeFS)
  end

  def open(path : Slice) : VFSNode?
    each_child do |node|
      return node if node.name == path
    end
  end

  def create(name : Slice) : VFSNode?
    each_child do |node|
      return if node.name == name
    end
    node = PipeFSNode.new(GcString.new(name), self, fs)
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
  getter name, fs

  @next_node : PipeFSNode? = nil
  property next_node

  @prev_node : PipeFSNode? = nil
  property prev_node

  def initialize(@name : GcString, @parent : PipeFSRoot, @fs : PipeFS)
    Serial.puts "mk ", @name, '\n'
  end

  @buffer = Pointer(UInt8).null
  @buffer_pos = 0
  BUFFER_CAPACITY = 0x1000

  def remove : Int32
    FrameAllocator.declaim_addr(@buffer.address & ~PTR_IDENTITY_MASK)
    @buffer = Pointer(UInt8).null
    @parent.remove self
    VFS_OK
  end

  private def init_buffer
    if @buffer.null?
      @buffer = Pointer(UInt8).new(FrameAllocator.claim_with_addr | PTR_IDENTITY_MASK)
    end
  end

  def read(slice : Slice, offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    # Serial.puts "read ", @name, " ", process.not_nil!.pid, '\n'
    init_buffer
    if @buffer_pos == 0
      0
    else
      # pop message from buffer
      size = min(slice.size, @buffer_pos)
      memcpy(slice.to_unsafe, @buffer + @buffer_pos - size, size.to_usize)
      @buffer_pos -= size
      size
    end
  end

  def write(slice : Slice, offset : UInt32,
            process : Multiprocessing::Process? = nil) : Int32
    # Serial.puts "write ", @name, " ", process.not_nil!.pid, '\n'
    init_buffer
    if @buffer_pos == BUFFER_CAPACITY
      0
    else
      # push the message on to the buffer stack
      size = min(slice.size, BUFFER_CAPACITY - @buffer_pos)
      memcpy(@buffer + @buffer_pos, slice.to_unsafe, size.to_usize)
      @buffer_pos += size
      size
    end
  end

  def truncate(size : Int32) : Int32
    if size < @buffer_pos
      @buffer_pos = size
    end
    @buffer_pos
  end

  def available?
    @buffer_pos > 0
  end
end

class PipeFS < VFS
  getter name

  def initialize
    @name = GcString.new "pipes"
    @root = PipeFSRoot.new self
  end

  def root
    @root.not_nil!
  end

end
