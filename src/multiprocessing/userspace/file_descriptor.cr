class FileDescriptor
  @node : VFSNode? = nil
  getter node

  @offset = 0u32
  property offset

  @buffering = VFSNode::Buffering::LineBuffered
  property buffering

  # used for readdir syscall
  @cur_child : VFSNode? = nil
  property cur_child
  @cur_child_end = false
  property cur_child_end

  @[Flags]
  enum Attributes
    Read  = 1 << 0
    Write = 1 << 1
    # creat
    Truncate = 1 << 3
    Append   = 1 << 4
  end

  getter idx, attrs

  def initialize(@idx : Int32, @node, @attrs : Attributes)
  end

  def clone(idx)
    @node.not_nil!.clone
    fd = FileDescriptor.new(idx, @node, @attrs)
    fd.offset = @offset
    fd.buffering = @buffering
    fd
  end
end
