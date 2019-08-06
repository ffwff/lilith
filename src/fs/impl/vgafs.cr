class VGAFsNode < VFSNode
  def initialize(@fs : VGAFS)
  end

  def open(path : Slice) : VFSNode?
    nil
  end

  def read(slice : Slice, offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    0
  end

  def write(slice : Slice) : Int32
    slice.each do |ch|
      VGA.puts ch.unsafe_chr
    end
    slice.size
  end

  def ioctl(request : Int32, data : Void*) : Int32
    case request
    when SC_IOCTL_TCSAFLUSH
      data = data.as(IoctlData::Termios*).value
      VgaState.echo_input = data.c_lflag.includes?(TermiosData::LFlag::ECHO)
      #Serial.puts "inputs: ", VgaState.echo_input?,'\n'
      0
    when SC_IOCTL_TCSAGETS
      IoctlHandler.tcsa_gets(data)
    when SC_IOCTL_TIOCGWINSZ
      IoctlHandler.winsize(data, VGA_WIDTH, VGA_HEIGHT, 0, 0)
    else
      -1
    end
  end

  def read_queue
    nil
  end
end

class VGAFS < VFS
  def name
    @name.not_nil!
  end

  @next_node : VFS? = nil
  property next_node

  def initialize
    @name = GcString.new "vga"
    @root = VGAFsNode.new self
  end

  def root
    @root.not_nil!
  end
end
