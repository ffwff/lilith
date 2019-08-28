class MemMapNode

  @[Flags]
  enum Attributes
    Read
    Write
    Execute
  end

  def initialize(@addr : UInt64, @size : UInt64, @attr : Attributes = Attributes::None)
  end

  def end_addr
    @addr + @size
  end

  @next_node : MemMapNode? = nil
  property next_node

  property addr, attr, size

  def to_s(io)
    io.puts Pointer(Void).new(@addr), ' '
    @size.to_s io, 16
    io.puts ' ', @attr
  end
end

class MemMapList
  @first_node : MemMapNode? = nil

  def add(addr : UInt64, size : UInt64, attr) : MemMapNode?
    end_addr = addr + size
    if @first_node.nil?
      node = MemMapNode.new(addr, size, attr)
      node.next_node = @first_node
      @first_node = node
      return node
    else
      # search for node before point of insertion
      current = @first_node.not_nil!
      while !current.next_node.nil? && current.next_node.not_nil!.addr < end_addr
        current = current.next_node.not_nil!
      end
      current = current.not_nil!
      if current.end_addr == addr && current.attr == attr
        # combine if 2 nodes represent a continuous region
        current.size += size
      else
        # create new node
        node = MemMapNode.new(addr, size, attr)
        node.next_node = current.next_node
        current.next_node = node
        return node
      end
    end
    nil
  end

  def remove(addr, size)
    panic "unimplemented"
  end

  def to_s(io)
    node = @first_node
    while !node.nil?
      io.puts node, '\n'
      node = node.not_nil!.next_node
    end
  end
end