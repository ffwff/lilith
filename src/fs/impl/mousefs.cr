private lib MouseFSData

  @[Packed]
  struct MousePacket
    x : UInt32
    y : UInt32
    attr_byte : UInt32
  end

end

class MouseFSNode < VFSNode
  getter fs, first_child

  def initialize(@fs : MouseFS)
    @first_child = MouseFSRawNode.new(fs)
  end

  def each_child(&block)
    node = first_child
    while !node.nil?
      yield node.not_nil!
      node = node.next_node
    end
  end

  def open(path)
    each_child do |node|
      if node.name == path
        return node
      end
    end
  end

  def read(slice : Slice, offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    remaining = slice.size
    idx = 0

    x, y, _ = fs.mouse.flush

    x.each_digit(10) do |ch|
      slice[idx] = ch
      idx += 1
      remaining -= 1
      return idx unless remaining > 0
    end

    slice[idx] = ','.ord.to_u8
    idx += 1
    remaining -= 1
    return idx unless remaining > 0

    y.each_digit(10) do |ch|
      slice[idx] = ch
      idx += 1
      remaining -= 1
      return idx unless remaining > 0
    end

    if remaining > 0
      slice[idx] = '\n'.ord.to_u8
      idx += 1
      remaining -= 1
    end

    idx
  end

end

class MouseFSRawNode < VFSNode
  getter fs, name

  def initialize(@fs : MouseFS)
    @name = GcString.new("raw")
  end

  def read(slice : Slice, offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    x, y, attr_byte = fs.mouse.flush

    packet = uninitialized MouseFSData::MousePacket
    packet.x = x
    packet.y = y
    packet.attr_byte = attr_byte.value
    size = min slice.size, sizeof(MouseFSData::MousePacket)
    memcpy(slice.to_unsafe, pointerof(packet).as(UInt8*), size.to_usize)

    size
  end

end


class MouseFS < VFS
  getter name

  getter mouse

  def initialize(@mouse : Mouse)
    @name = GcString.new "mouse"
    @root = MouseFSNode.new self
    @mouse.mousefs = self
  end

  def root
    @root.not_nil!
  end
end
