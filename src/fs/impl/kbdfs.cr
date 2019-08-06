class KbdFsNode < VFSNode
  @read_queue : VFSReadQueue? = nil
  getter read_queue

  def initialize
    @read_queue = VFSReadQueue.new
  end

  def open(path : Slice) : VFSNode?
    nil
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
    Idt.lock do
      last_page_dir = Paging.current_page_dir
      root.read_queue.not_nil!.keep_if do |msg|
        dir = msg.process.phys_page_dir
        Paging.current_page_dir = Pointer(PageStructs::PageDirectory).new(dir.to_u64)
        Paging.enable
        case msg.buffering
        when VFSNode::Buffering::Unbuffered
          msg.respond ch.ord.to_u8
          msg.process.status = Multiprocessing::Process::Status::Unwait
          msg.process.frame.not_nil!.eax = 1
          false
        else
          if ch == '\b' && msg.offset > 0
            msg.respond 0
            false
          else
            msg.respond ch.ord.to_u8
            if (msg.buffering == VFSNode::Buffering::LineBuffered && ch == '\n') ||
                msg.finished?
              msg.process.status = Multiprocessing::Process::Status::Unwait
              msg.process.frame.not_nil!.eax = msg.offset
              false
            else
              true
            end
          end
        end
      end

      Paging.current_page_dir = last_page_dir
      Paging.enable
    end
  end
end
