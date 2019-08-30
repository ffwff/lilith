class PipeFSRoot < VFSNode
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

  def initialize(@name : GcString, @parent : PipeFSRoot, @fs : PipeFS)
  end

  def open(path : Slice) : VFSNode?
    nil
  end

  def create(name : Slice) : VFSNode?
    nil
  end

  @buffer = Pointer(UInt8).null
  @buffer_pos = 0
  BUFFER_CAPACITY = 0x1000

  private def init_buffer
    if @buffer.null?
      @buffer = Pointer(UInt8).new(FrameAllocator.claim_with_addr | PTR_IDENTITY_MASK)
    end
  end

  def read(slice : Slice, offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    init_buffer
    if @buffer_pos == 0
      # TODO
      VFS_ERR
    else
      # pop message from buffer
      size = min(slice.size, @buffer_pos)
      memcpy(slice.to_unsafe, @buffer, size.to_usize)
      @buffer_pos -= size
      size
    end
  end

  def write(slice : Slice, offset : UInt32,
            process : Multiprocessing::Process? = nil) : Int32
    init_buffer
    if @buffer_pos == BUFFER_CAPACITY
      # TODO
      VFS_ERR
    else
      # push the message on to the buffer stack
      size = min(slice.size, BUFFER_CAPACITY - @buffer_pos)
      memcpy(@buffer, slice.to_unsafe, size.to_usize)
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
