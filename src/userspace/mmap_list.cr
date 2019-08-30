class MemMapNode

  @[Flags]
  enum Attributes
    Read
    Write
    Execute
  end

  @next_node : MemMapNode? = nil
  property next_node

  @prev_node : MemMapNode? = nil
  property prev_node

  property addr, attr, size

  def initialize(@addr : UInt64, @size : UInt64, @attr : Attributes = Attributes::None)
  end

  def end_addr
    @addr + @size
  end

  def to_s(io)
    io.puts Pointer(Void).new(@addr), ' '
    @size.to_s io, 16
    io.puts ' ', @attr
  end
end

class MemMapList
  @first_node : MemMapNode? = nil
  @last_node : MemMapNode? = nil

  def add(addr : UInt64, size : UInt64, attr) : MemMapNode?
    end_addr = addr + size
    if @first_node.nil? || end_addr < @first_node.not_nil!.addr
      node = MemMapNode.new(addr, size, attr)
      node.next_node = @first_node
      if node.next_node.nil?
        @last_node = node
      end
      @first_node = node
      return node
    else
      # search for node before point of insertion
      current = @first_node.not_nil!
      while !current.next_node.nil? && current.next_node.not_nil!.addr < end_addr
        current = current.next_node.not_nil!
      end
      current = current.not_nil!

      combine_with_prev = current.attr == attr && current.end_addr == addr
      combine_with_next = !current.next_node.nil? &&
          current.next_node.not_nil!.attr == attr &&
          end_addr == current.next_node.not_nil!.addr

      # combine if 2 nodes represent a continuous region
      if combine_with_prev && combine_with_next
        # insertion node is between 2 continue nodes
        next_node = current.next_node.not_nil!
        next_next_node = next_node.next_node

        current.next_node = next_next_node
        current.size += size + next_node.size
      elsif combine_with_prev
        # current node is before insertion node
        current.size += size
      elsif combine_with_next
        # insertion node is before continued node
        next_node = current.next_node.not_nil!
        next_node.addr = addr
        next_node.size += size
      else
        # create new node
        node = MemMapNode.new(addr, size, attr)
        node.prev_node = current
        node.next_node = current.next_node
        current.next_node = node
        if node.next_node.nil?
          @last_node = node.next_node
        end
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