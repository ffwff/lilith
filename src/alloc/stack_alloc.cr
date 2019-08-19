class StackAllocator

  @offset = 0u64

  def initialize(@pointer : Void*)
  end

  def malloc(sz)
    offset = @offset
    @offset += sz
    @pointer + offset
  end

  def clear
    @offset = 0u64
  end

end