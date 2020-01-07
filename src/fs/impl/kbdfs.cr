module KbdFS
  extend self

  lib Data
    @[Packed]
    struct Packet
      ch : Int32
      modifiers : Int32
    end
  end

  class Node < VFS::Node
    include VFS::Enumerable(VFS::Node)

    getter fs : VFS::FS, raw_node, first_child

    def initialize(@fs : FS)
      @raw_node = @first_child = RawNode.new(fs)
      @attributes |= VFS::Node::Attributes::Directory
    end

    def read(slice : Slice, offset : UInt32,
             process : Multiprocessing::Process? = nil) : Int32
      if @fs.ansi_remaining > 0
        size = Math.min @fs.ansi_remaining, slice.size
        size.times do |i|
          slice[i] = @fs.ansi_buf_pop
        end
        return size
      end
      VFS_WAIT
    end

    def ioctl(request : Int32, data : UInt64,
              process : Multiprocessing::Process? = nil) : Int32
      case request
      when SC_IOCTL_TCSAFLUSH
        data = checked_pointer(IoctlHandler::Data::Termios, data)
        return -1 if data.nil?
        data = data.not_nil!.value
        @fs.echo_input = data.c_lflag.includes?(IoctlHandler::Data::LFlag::ECHO)
        @fs.canonical = data.c_lflag.includes?(IoctlHandler::Data::LFlag::ICANON)
        0
      when SC_IOCTL_TCSAGETS
        data = checked_pointer(IoctlHandler::Data::Termios, data)
        return -1 if data.nil?
        IoctlHandler.tcsa_gets(data.not_nil!) do |termios|
          if @fs.echo_input
            termios.c_lflag |= IoctlHandler::Data::LFlag::ECHO
          end
          if @fs.canonical
            termios.c_lflag |= IoctlHandler::Data::LFlag::ICANON
          end
          termios
        end
      else
        -1
      end
    end
  end

  class RawNode < VFS::Node
    getter fs : VFS::FS

    def initialize(@fs : FS)
    end

    def name
      "raw"
    end

    @ch = 0
    @modifiers = 0
    @packet_available = false
    property ch, modifiers, packet_available

    def read(slice : Slice, offset : UInt32,
             process : Multiprocessing::Process? = nil) : Int32
      @packet_available = false
      packet = uninitialized Data::Packet
      packet.ch = @ch
      packet.modifiers = @modifiers
      @ch = 0
      @modifiers = 0
      size = Math.min slice.size, sizeof(Data::Packet)
      memcpy(slice.to_unsafe, pointerof(packet).as(UInt8*), size.to_usize)
      size
    end

    def available?(process : Multiprocessing::Process) : Bool
      @packet_available
    end
  end

  class FS < VFS::FS
    getter! root : VFS::Node
    getter queue : VFS::Queue?

    def initialize(@kbd : Keyboard)
      @root = Node.new self
      @kbd.kbdfs = self
      @queue = VFS::Queue.new
    end

    def name : String
      "kbd"
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
      elsif !Console.locked?
        if ch == '\n' && !@canonical
          Console.newline
        elsif should_print ch
          Console.print ch
        end
      end

      @root.not_nil!.raw_node.ch = ch.ord.to_i32
      @root.not_nil!.raw_node.modifiers = @kbd.modifiers.value
      @root.not_nil!.raw_node.packet_available = true

      @queue.not_nil!.keep_if do |msg|
        case msg.buffering
        when VFS::Node::Buffering::Unbuffered
          msg.respond n
          msg.unawait
          false
        else
          if ch == '\b'
            msg.consume
            true
          else
            msg.respond n
            if (msg.buffering == VFS::Node::Buffering::LineBuffered && ch == '\n') ||
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
        size = Math.min(ansi_remaining, msg.slice_size)
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
      i = Math.min str.size, @ansi_buf.size
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
end
