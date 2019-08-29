class ConsoleFsNode < VFSNode
  getter fs

  def initialize(@fs : ConsoleFS)
  end

  def open(path : Slice) : VFSNode?
    nil
  end

  def create(name : Slice) : VFSNode?
    nil
  end

  def read(slice : Slice, offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    0
  end

  def write(slice : Slice, offset : UInt32,
            process : Multiprocessing::Process? = nil) : Int32
    slice.each do |ch|
      Console.puts ch.unsafe_chr
    end
    slice.size
  end

  def ioctl(request : Int32, data : Void*) : Int32
    case request
    when SC_IOCTL_TIOCGWINSZ
      IoctlHandler.winsize(data, Console.width, Console.height, 0, 0)
    else
      -1
    end
  end

  def read_queue
    nil
  end
end

class ConsoleFS < VFS
  def name
    @name.not_nil!
  end

  def initialize
    @name = GcString.new "con"
    @root = ConsoleFsNode.new self
  end

  def root
    @root.not_nil!
  end
end
