class MouseFsNode < VFSNode
  getter fs

  def initialize(@fs : MouseFS)
  end

  def open(path : Slice) : VFSNode?
    nil
  end

  def read(slice : Slice, offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    remaining = slice.size
    idx = 0

    fs.mouse.x.each_digit(10) do |ch|
      slice[idx] = ch
      idx += 1
      remaining -= 1
      return idx unless remaining > 0
    end

    slice[idx] = ','.ord.to_u8
    idx += 1
    remaining -= 1
    return idx unless remaining > 0

    fs.mouse.y.each_digit(10) do |ch|
      slice[idx] = ch
      idx += 1
      remaining -= 1
      return idx unless remaining > 0
    end

    idx
  end

  def write(slice : Slice) : Int32
    0
  end

  def ioctl(request : Int32, data : Void*) : Int32
    -1
  end
end

class MouseFS < VFS
  getter name

  @next_node : VFS? = nil
  property next_node

  getter mouse

  def initialize(@mouse : Mouse)
    @name = GcString.new "mouse"
    @root = MouseFsNode.new self
    @mouse.mousefs = self
  end

  def root
    @root.not_nil!
  end
end
