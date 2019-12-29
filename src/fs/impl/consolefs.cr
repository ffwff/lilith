class ConsoleFS::Node < VFS::Node
  getter fs : VFS::FS

  def initialize(@fs : ConsoleFS::FS)
  end

  def read(slice : Slice, offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    0
  end

  def write(slice : Slice, offset : UInt32,
            process : Multiprocessing::Process? = nil) : Int32
    VFS_WAIT
  end

  def ioctl(request : Int32, data : UInt64,
            process : Multiprocessing::Process? = nil) : Int32
    case request
    when SC_IOCTL_TIOCGWINSZ
      unless (ptr = checked_pointer(IoctlHandler::Data::Winsize, data)).nil?
        IoctlHandler.winsize(ptr.not_nil!, Console.width, Console.height, 1, 1)
      else
        -1
      end
    when SC_IOCTL_TIOCGSTATE
      Console.enabled = data == 1
      Console.enabled ? 1 : 0
    else
      -1
    end
  end

  def read_queue
    nil
  end
end

class ConsoleFS::FS < VFS::FS
  getter! root : VFS::Node

  def name : String
    "con"
  end

  def initialize
    @root = ConsoleFS::Node.new self

    # setup process-local variables
    @process = Multiprocessing::Process
      .spawn_kernel("[consolefs]",
        ->(ptr : Void*) { ptr.as(ConsoleFS::FS).process },
        self.as(Void*),
        stack_pages: 2) do |process|
    end
    @queue = VFS::Queue.new(@process)
  end

  getter queue

  protected def process
    while true
      unless (msg = @queue.not_nil!.dequeue).nil?
        case msg.type
        when VFS::Message::Type::Write
          msg.read do |ch|
            Console.print ch.unsafe_chr
          end
          msg.unawait(msg.slice_size)
        end
      else
        Multiprocessing.sleep_drv
      end
    end
  end
end
