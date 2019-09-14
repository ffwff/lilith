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
  
  getter idx

  def initialize(@idx : Int32, @node)
  end

  def clone(idx)
    fd = FileDescriptor.new(idx, @node)
    fd.offset = @offset
    fd.buffering = @buffering
    fd
  end
end
