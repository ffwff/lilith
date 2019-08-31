class MouseFsNode < VFSNode
  getter fs

  def initialize(@fs : MouseFS)
  end

  def open(path : Slice) : VFSNode?
    nil
  end

  def create(name : Slice) : VFSNode?
    nil
  end

  def read(slice : Slice, offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    remaining = slice.size
    idx = 0

    x, y = fs.mouse.flush

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

  def write(slice : Slice, offset : UInt32,
            process : Multiprocessing::Process? = nil) : Int32
    VFS_ERR
  end

  def ioctl(request : Int32, data : Void*) : Int32
    -1
  end
end

class MouseFS < VFS
  getter name

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
