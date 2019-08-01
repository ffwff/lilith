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

  def initialize(@node)
  end
end
