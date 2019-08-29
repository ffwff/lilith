class ShmemChunk

  @refs = 1

  def ref
    @refs += 1
  end

  def unref
    @refs -= 1
    if @refs == 0
      FrameAllocator.declaim_addr(@phys_addr)
      @phys_addr = 0u64
      @size = 0u64
    end
  end

  def initialize(@phys_addr : UInt64, @size : UInt64)
  end

end

class ShmemMappingNode

  getter addr, chunk

  def initialize(@addr : UInt64, @chunk : ShmemChunk)
    @chunk.ref
  end

end

class ShmemMapping
  @first_node : ShmemMappingNode? = nil

  def initialize(@node : MemMapNode)
  end

end