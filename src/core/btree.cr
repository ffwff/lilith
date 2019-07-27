class BTreeNode(K, V)
  def initialize(@key : K, @value : V, @left : BTreeNode(K, V)? = nil, @right : BTreeNode(K, V)? = nil)
  end

  property key, value, left, right

  def insert(key, value)
    if key == @key
      @value = value
    elsif key < @key
      if @left.nil?
        @left = BTreeNode(K, V).new key, value
      else
        @left.not_nil!.insert key, value
      end
    elsif key > @key
      if @right.nil?
        @right = BTreeNode(K, V).new key, value
      else
        @right.not_nil!.insert key, value
      end
    end
  end

  def search(key)
    if key == @key
      @value
    elsif key < @key
      if @left.nil?
        nil
      else
        @left.not_nil!.search key
      end
    else
      if @right.nil?
        nil
      else
        @right.not_nil!.search key
      end
    end
  end

  def to_s(io)
    io.puts "[", @key, ": ", @value, "]"
    io.puts "( "
    @left.to_s io
    io.puts " "
    @right.to_s io
    io.puts " )"
  end
end

class BTree(K, V)
  def initialize(@root : BTreeNode(K, V)? = nil)
  end

  property root

  def insert(key, value)
    if @root.nil?
      @root = BTreeNode(K, V).new key, value
    else
      @root.not_nil!.insert key, value
    end
  end

  def search(key)
    if @root.nil?
      nil
    else
      @root.not_nil!.search key
    end
  end

  def balance(nelems)
    # turn into sorted linked list
    proot = BTreeNode(K, V).new(root.not_nil!.key, root.not_nil!.value, nil, root)
    tail = proot
    rest = tail.right
    while !rest.nil?
      rest = rest.not_nil!
      if rest.left.nil?
        tail = rest
        rest = rest.right
      else
        temp = rest.left.not_nil!
        rest.left = temp.right
        temp.right = rest
        rest = temp
        tail.right = temp
      end
    end

    # balance it
    leaves = nelems + 1 - nelems.lowest_power_of_2
    compress proot, leaves
    nelems -= leaves
    while nelems > 1
      nelems = nelems.unsafe_div(2)
      compress proot, nelems
    end
    @root = proot.right
  end

  private def compress(root, count)
    scanner = root.not_nil!
    i = 1
    while i < count
      child = scanner.right.not_nil!
      scanner.right = child.right
      scanner = scanner.right.not_nil!
      child.right = scanner.left
      scanner.left = child
      i += 1
    end
  end

  def to_s(io)
    if @root.nil?
      io.puts "()"
    else
      io.puts @root
    end
  end
end
