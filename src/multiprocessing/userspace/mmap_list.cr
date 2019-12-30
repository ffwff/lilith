class MemMapList
  class Node
    @[Flags]
    enum Attributes
      Read
      Write
      Execute
      Stack
      SharedMem
    end

    def combinable_attrs(attr)
      if @attr.includes?(Attributes::SharedMem) ||
         attr.includes?(Attributes::SharedMem)
        return false
      end
      true
    end

    def contains_address?(address : UInt64)
      @addr <= address <= end_addr
    end

    @next_node : MemMapList::Node? = nil
    property next_node

    @prev_node : MemMapList::Node? = nil
    property prev_node

    property addr, attr, size

    @shm_node : VFS::Node? = nil
    property shm_node

    def initialize(@addr : UInt64, @size : UInt64, @attr : Attributes = Attributes::None)
    end

    def end_addr
      @addr + @size
    end

    def each_page(&block)
      i = 0
      while i < @size
        yield @addr + i
        i += 0x1000
      end
    end

    def handle_page_fault(present, rw, user, page : UInt64)
      if @attr.includes?(Attributes::Stack)
        unless present
          Paging.alloc_page_pg page, true, true, 1
          zero_page Pointer(UInt8).new(page)
          return true
        end
      end
      false
    end

    def to_s(io)
      io.print Pointer(Void).new(@addr), ' '
      @size.to_s io, 16
      io.print ' ', @attr
    end
  end

  @first_node : MemMapList::Node? = nil
  @last_node : MemMapList::Node? = nil

  def add(addr : UInt64, size : UInt64, attr) : MemMapList::Node?
    end_addr = addr + size
    if @first_node.nil? || end_addr < @first_node.not_nil!.addr
      node = MemMapList::Node.new(addr, size, attr)
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

      combine_with_prev = current.combinable_attrs(attr) && current.end_addr == addr
      combine_with_next = !current.next_node.nil? &&
                          current.next_node.not_nil!.combinable_attrs(attr) &&
                          end_addr == current.next_node.not_nil!.addr

      # combine if 2 nodes represent a continuous region
      if combine_with_prev && combine_with_next
        # insertion node is between 2 continue nodes
        next_node = current.next_node.not_nil!
        next_next_node = next_node.next_node

        current.next_node = next_next_node
        if n = next_next_node
          n.prev_node = current
        end
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
        node = MemMapList::Node.new(addr, size, attr)
        node.prev_node = current
        node.next_node = current.next_node
        if nn = current.next_node
          nn.prev_node = node
        else
          @last_node = node
        end
        current.next_node = node
        return node
      end
    end
    nil
  end

  def remove(addr, size)
    abort "unimplemented"
  end

  def remove(node : MemMapList::Node)
    if node.prev_node
      node.prev_node.not_nil!.next_node = node.next_node
    else
      @first_node = node.next_node
    end
    if node.next_node
      node.next_node.not_nil!.prev_node = node.prev_node
    else
      @last_node = node.prev_node
    end
  end

  def space_for_mmap(process : Multiprocessing::Process, size : UInt64, attr : MemMapList::Node::Attributes)
    # look backwards from the stack
    reverse_each do |node|
      return if node.prev_node.nil?
      prev_node = node.prev_node.not_nil!

      # don't allocate in the middle of the stack
      next if node.attr.includes?(MemMapList::Node::Attributes::Stack) &&
              prev_node.attr.includes?(MemMapList::Node::Attributes::Stack)

      start_addr = prev_node.end_addr
      end_addr = node.addr
      if process.udata.is64 && end_addr > Multiprocessing::USER_MMAP_INITIAL64
        end_addr = Multiprocessing::USER_MMAP_INITIAL64
      elsif !process.udata.is64 && end_addr > Multiprocessing::USER_MMAP_INITIAL
        end_addr = Multiprocessing::USER_MMAP_INITIAL
      end
      mmap_size = end_addr - start_addr

      if mmap_size < size
        next
      elsif mmap_size > size
        # shrink to fit
        mmap_size = size
        start_addr = end_addr - mmap_size
      end

      new_node = MemMapList::Node.new(start_addr, size, attr)
      prev_node.next_node = new_node
      new_node.prev_node = prev_node
      node.prev_node = new_node
      new_node.next_node = node

      return new_node
    end
  end

  def reverse_each(&block)
    node = @last_node
    until node == @first_node
      yield node.not_nil!
      node = node.not_nil!.prev_node
    end
  end

  def each(&block)
    node = @first_node
    while !node.nil?
      yield node.not_nil!
      node = node.not_nil!.next_node
    end
  end

  def to_s(io)
    each do |node|
      io.print node, '\n'
    end
  end
end
