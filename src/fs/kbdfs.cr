require "./vfs.cr"

class KbdFsNode < VFSNode
  @read_queue : VFSReadQueue? = nil
  getter read_queue

  def initialize
    @read_queue = VFSReadQueue.new
  end

  #
  def size : Int
    0
  end

  def name; end

  def parent; end

  def next_node; end

  def first_child; end

  #
  def open(path : Slice) : VFSNode?
    nil
  end

  def read(&block)
  end

  def read(slice : Slice, offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    VFS_READ_WAIT
  end

  def write(slice : Slice) : Int32
    0
  end
end

class KbdFS < VFS
  def name
    @name.not_nil!
  end

  @next_node : VFS? = nil
  property next_node

  def initialize(kbd : Keyboard)
    @name = GcString.new "kbd"
    @root = KbdFsNode.new
    kbd.kbdfs = self
  end

  def root
    @root.not_nil!
  end

  def on_key(ch)
    VGA.puts ch

    Idt.lock do
      last_page_dir = Paging.current_page_dir
      root.read_queue.not_nil!.keep_if do |msg|
        dir = msg.process.phys_page_dir
        Paging.current_page_dir = Pointer(PageStructs::PageDirectory).new(dir.to_u64)
        Paging.enable
        msg.slice[0] = ch.ord.to_u8
        msg.process.status = Multiprocessing::Process::Status::Unwait
        msg.process.frame.not_nil!.eax = 1
        false
      end

      Paging.current_page_dir = last_page_dir
      Paging.enable
    end
  end
end
