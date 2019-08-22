class KbdFsNode < VFSNode
  getter fs

  def initialize(@fs : KbdFS)
  end

  def open(path : Slice) : VFSNode?
    nil
  end

  def read(slice : Slice, offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    if @fs.ansi_remaining > 0
      size = min @fs.ansi_remaining, slice.size
      size.times do |i|
        slice[i] = @fs.ansi_buf_pop
      end
      return size
    end
    VFS_WAIT
  end

  def write(slice : Slice, offset : UInt32,
            process : Multiprocessing::Process? = nil) : Int32
    VFS_ERR
  end

  def ioctl(request : Int32, data : Void*) : Int32
    case request
    when SC_IOCTL_TCSAFLUSH
      data = data.as(IoctlData::Termios*).value
      @fs.echo_input = data.c_lflag.includes?(TermiosData::LFlag::ECHO)
      @fs.canonical = data.c_lflag.includes?(TermiosData::LFlag::ICANON)
      0
    when SC_IOCTL_TCSAGETS
      IoctlHandler.tcsa_gets(data) do |termios|
        if @fs.echo_input
          termios.c_lflag |= TermiosData::LFlag::ECHO
        end
        if @fs.canonical
          termios.c_lflag |= TermiosData::LFlag::ICANON
        end
        termios
      end
    else
      -1
    end
  end

end

class KbdFS < VFS
  getter name

  @next_node : VFS? = nil
  property next_node

  getter queue

  def initialize(@kbd : Keyboard)
    @name = GcString.new "kbd"
    @root = KbdFsNode.new self
    @kbd.kbdfs = self
    @queue = VFSQueue.new
  end

  def root
    @root.not_nil!
  end

  @echo_input = true
  property echo_input
  @canonical = true
  property canonical

  private def should_print(ch)
    if ch.ord >= 0x20 && ch.ord <= 0x7e
      if !@echo_input
        return false
      end
    end
    true
  end

  def on_key(ch : Char)
    n = ch.ord.to_u8

    if @kbd.modifiers.includes?(Keyboard::Modifiers::CtrlL) ||
       @kbd.modifiers.includes?(Keyboard::Modifiers::CtrlR)
      n = (case ch
      when 'c'
        3
      when 'd'
        4
      when 'f'
        6
      when 'h'
        5
      when 'l'
        12
      when 'q'
        17
      when 's'
        19
      when 'u'
        21
      else
        return
      end).to_u8
    else
      if ch == '\n' && !@canonical
        Console.newline
      elsif should_print ch
        Console.puts ch
      end
    end

    @queue.not_nil!.keep_if do |msg|
      case msg.buffering
      when VFSNode::Buffering::Unbuffered
        msg.respond n
        msg.unawait
        false
      else
        if ch == '\b' && msg.offset > 0
          msg.respond 0
          false
        else
          msg.respond n
          if (msg.buffering == VFSNode::Buffering::LineBuffered && ch == '\n') ||
              msg.finished?
            msg.unawait
            false
          else
            true
          end
        end
      end
    end

  end

  def on_key(key : Keyboard::SpecialKeys)
    case key
    when Keyboard::SpecialKeys::UpArrow
      ansi_buf_set StaticArray[0x1B, '['.ord, 'A'.ord]
    when Keyboard::SpecialKeys::DownArrow
      ansi_buf_set StaticArray[0x1B, '['.ord, 'B'.ord]
    when Keyboard::SpecialKeys::RightArrow
      ansi_buf_set StaticArray[0x1B, '['.ord, 'C'.ord]
    when Keyboard::SpecialKeys::LeftArrow
      ansi_buf_set StaticArray[0x1B, '['.ord, 'D'.ord]
    when Keyboard::SpecialKeys::Delete
      ansi_buf_set StaticArray[0x1B, '['.ord, '3'.ord, '~'.ord]
    end

    queue.not_nil!.keep_if do |msg|
      size = min(ansi_remaining, msg.slice_size)
      size.times do |i|
        msg.respond ansi_buf_pop
      end
      msg.unawait
      false
    end
  end

  # buffer to store ansi characters
  @ansi_buf = uninitialized UInt8[16]
  @ansi_remaining = 0
  getter ansi_remaining

  private def ansi_buf_set(str)
    i = min str.size, @ansi_buf.size
    @ansi_remaining = i
    i -= 1
    j = 0
    while j < @ansi_remaining
      @ansi_buf[j] = str[i].to_u8
      i -= 1
      j += 1
    end
  end

  def ansi_buf_pop
    @ansi_remaining -= 1
    ch = @ansi_buf[@ansi_remaining]
    ch
  end

end
