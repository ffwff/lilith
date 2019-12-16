require "./wm/*"
require "./painter/*"
require "socket"

lib LibC
  @[Packed]
  struct Winsize
    ws_row : UInt16
    ws_col : UInt16
    ws_xpixel : UInt16
    ws_ypixel : UInt16
  end
  TIOCGWINSZ = 2
  TIOCGSTATE = 5

  enum MouseAttributes : UInt32
    LeftButton   = 1 << 0
    RightButton  = 1 << 1
    MiddleButton = 1 << 2
  end

  @[Packed]
  struct MousePacket
    x : UInt32
    y : UInt32
    attributes : MouseAttributes
    scroll_delta : Int8
  end

  @[Packed]
  struct KeyboardPacket
    ch : Int32
    modifiers : Int32
  end
end

CURSOR_FILE = "/hd0/share/cursors/cursor.png"

@[NoInline]
fun breakpoint
  asm("nop")
end

module Wm::Server
  extend self

  abstract class Window
    @x : Int32 = 0
    @y : Int32 = 0
    @z_index : Int32 = 0
    property x, y, z_index

    @bitmap : Painter::Bitmap? = nil
    getter! bitmap
    setter bitmap

    abstract def render(bitmap : Painter::Bitmap)

    def <=>(other)
      @z_index <=> other.z_index
    end
    
    def contains_point?(x : Int, y : Int)
      bitmap = @bitmap.not_nil!
      @x <= x && x <= (@x + bitmap.width) &&
      @y <= y && y <= (@y + bitmap.height)
    end
  end

  class Background < Window
    def initialize(@color : UInt32)
      @z_index = -1
    end

    def render(buffer : Painter::Bitmap)
      Painter.blit_u32(buffer.to_unsafe, @color, Server.framebuffer.width.to_usize * Server.framebuffer.height.to_usize)
    end
    
    def contains_point?(x : Int, y : Int)
      true
    end
  end

  class Cursor < Window
    def initialize
      @bitmap = Painter.load_png(CURSOR_FILE).not_nil!
      @z_index = Int32::MAX
    end

    def render(buffer : Painter::Bitmap)
      Painter.blit_img buffer, bitmap.not_nil!, @x, @y, true
    end

    def respond(file)
      packet = LibC::MousePacket.new
      file.read(Bytes.new(pointerof(packet).as(UInt8*), sizeof(LibC::MousePacket)))
      speed = Math.log2(packet.x + packet.y)
      if packet.x != 0
        delta_x = packet.x * speed
        @x = @x + delta_x
        @x = @x.clamp(0, Server.framebuffer.width)
      else
        delta_x = 0
      end
      if packet.y != 0
        delta_y = -packet.y * speed
        @y = @y + delta_y
        @y = @y.clamp(0, Server.framebuffer.height)
      else
        delta_y = 0
      end
      packet
    end
  end

  class Program < Window
    class Socket < IO::FileDescriptor
      @program : Program? = nil
      property program

      def initialize(@fd)
        self.buffer_size = 0
      end
    end

    @socket : Program::Socket
    @wid : Int32
    @bitmap_file : File

    getter socket, wid, bitmap

    def initialize(@socket, @x, @y, width, height)
      @wid = Server.next_wid
      @bitmap_file = File.new("/tmp/wm-bm:" + @wid.to_s, "rw").not_nil!
      @bitmap_file.truncate width * height * 4
      @bitmap = Painter::Bitmap.new(width, height, @bitmap_file.map_to_memory(prot: LibC::MmapProt::Read).as(UInt32*))
    end

    def render(buffer : Painter::Bitmap)
      Painter.blit_img buffer, bitmap.not_nil!, @x, @y
    end
  end

  @@framebuffer : Painter::Bitmap? = nil
  protected class_getter! framebuffer
  @@backbuffer : Painter::Bitmap? = nil
  protected class_getter! backbuffer

  @@windows = Array(Window).new 4
  @@focused : Window?

  @@fb : File?
  class_getter! fb

  # window id
  @@wid = 0
  def next_wid
    i = @@wid
    @@wid += 1
    i
  end
  @@focused : Program?

  # io selector
  @@selector : IO::Select? = nil
  class_getter! selector

  # client sockets
  @@clients : Array(Program::Socket)? = nil
  class_getter! clients

  # raw mouse hardware file
  @@mouse : File? = nil
  class_getter! mouse

  # raw keyboard hardware file
  @@kbd : File? = nil
  class_getter! kbd

  # window representing the cursor
  @@cursor : Cursor? = nil
  class_getter! cursor

  # communication server
  @@ipc : IPCServer? = nil
  class_getter! ipc

  def init
    unless (@@fb = File.new("/fb0", "r"))
      abort "unable to open /fb0"
    end
    @@selector = IO::Select.new
    @@clients = Array(Program::Socket).new

    ws = uninitialized LibC::Winsize
    LibC._ioctl(fb.fd, LibC::TIOCGWINSZ, pointerof(ws).address)

    @@framebuffer = Painter::Bitmap.new ws.ws_col.to_i32, ws.ws_row.to_i32,
      fb.map_to_memory(prot: LibC::MmapProt::Read | LibC::MmapProt::Write).as(UInt32*)
    @@backbuffer = Painter::Bitmap.new framebuffer.width, framebuffer.height

    @@focused = nil

    LibC._ioctl STDOUT.fd, LibC::TIOCGSTATE, 0

    # communication pipe
    if @@ipc = IPCServer.new("wm")
      selector << ipc
    else
      abort "unable to create communication pipe"
    end

    # wallpaper
    @@windows.push Background.new(0x000066cc)

    # keyboard
    if (@@kbd = File.new("/kbd/raw", "r"))
      selector << kbd
    else
      abort "unable to open /kbd/raw"
    end

    # mouse
    if (@@mouse = File.new("/mouse/raw", "r"))
      selector << mouse
    else
      abort "unable to open /mouse/raw"
    end
    @@cursor = Cursor.new
    @@windows.push cursor

    # default startup application
    #Process.new "desktop",
    #  input: Process::Redirect::Inherit,
    #  output: Process::Redirect::Inherit,
    #  error: Process::Redirect::Inherit
  end


  def loop
    while true
      selected = selector.wait(1)
      case selected
      when kbd
        respond_kbd
      when mouse
        respond_mouse
      when ipc
        respond_ipc
      else
        abort "unhandled socket" unless selected.nil?
      end
      clients.each do |socket|
        respond_ipc_socket socket
      end
      @@windows.each do |window|
        window.render backbuffer
      end
      LibC.memcpy framebuffer.to_unsafe, backbuffer.to_unsafe,
        (framebuffer.width.to_usize * framebuffer.height.to_usize * 4)
    end
  end

  def respond_kbd
    packet = uninitialized LibC::KeyboardPacket
    if kbd.unbuffered_read(Bytes.new(pointerof(packet).as(UInt8*), sizeof(LibC::KeyboardPacket))) \
      != sizeof(LibC::KeyboardPacket)
      return
    end
    if focused = @@focused
      focused.socket.unbuffered_write IPC.kbd_event_message(packet.ch, packet.modifiers).to_slice
    end
  end

  def respond_mouse
    packet = cursor.respond mouse
    
    modifiers = IPC::Data::MouseEventModifiers.new 0
    if packet.attributes.includes?(LibC::MouseAttributes::LeftButton)
      modifiers |= IPC::Data::MouseEventModifiers::LeftButton
    end
    if packet.attributes.includes?(LibC::MouseAttributes::RightButton)
      modifiers |= IPC::Data::MouseEventModifiers::RightButton
    end
    if packet.attributes.includes?(LibC::MouseAttributes::MiddleButton)
      modifiers |= IPC::Data::MouseEventModifiers::MiddleButton
    end
    
    if (focused = @@focused) && focused.contains_point?(cursor.x, cursor.y)
      focused.socket.unbuffered_write IPC.mouse_event_message(cursor.x, cursor.y, modifiers, packet.scroll_delta).to_slice
    end
    if modifiers.includes?(IPC::Data::MouseEventModifiers::LeftButton)
      @@windows.reverse_each do |win|
        case win
        when Program
          win = win.as(Program)
          if win.contains_point?(cursor.x, cursor.y) && win.z_index != -1
            break if win == @@focused
            if focused = @@focused
              focused.socket.unbuffered_write IPC.refocus_event_message(win.wid, 0).to_slice
              focused.z_index = 1
            end
            @@focused = win
            win.socket.unbuffered_write IPC.refocus_event_message(win.wid, 1).to_slice
            win.z_index = 2
            @@windows.sort!
            break
          end
        end
      end
    end
  end

  def respond_ipc
    if socket = ipc.accept?
      psocket = Program::Socket.new(socket.fd)
      clients.push psocket
    end
  end

  private struct FixedMessageReader(T)
    def self.read(header, socket)
      msg = uninitialized T
      msg.header = header
      payload = IPC.payload_bytes(msg)
      return if payload.size != header.length
      return if socket.unbuffered_read(payload) != payload.size
      return if !IPC.valid_msg?(Bytes.new(pointerof(msg).as(UInt8*), sizeof(T)))
      msg
    end
  end

  def respond_ipc_socket(socket)
    while true
      header = uninitialized IPC::Data::Header
      if socket.unbuffered_read(Bytes.new(pointerof(header).as(UInt8*),
                                          sizeof(IPC::Data::Header))) \
          != sizeof(IPC::Data::Header)
        return
      end
      case header.type
      when IPC::Data::TEST_MESSAGE_ID
        STDERR.puts "test message!"
      when IPC::Data::WINDOW_CREATE_ID
        if (msg = FixedMessageReader(IPC::Data::WindowCreate).read(header, socket))
          unless socket.program.nil?
            socket.unbuffered_write IPC.response_message(-1).to_slice
            next
          end

          if msg.flags.includes?(IPC::Data::WindowFlags::Background)
            case @@windows[0]
            when Background
            else
              socket.unbuffered_write IPC.response_message(-1).to_slice
              next
            end
          end

          if focused = @@focused
            focused.socket.unbuffered_write IPC.refocus_event_message(focused.wid, 0).to_slice
          end
          socket.program = program = Program.new(socket, msg.x, msg.y, msg.width, msg.height)
          @@focused = program
          if msg.flags.includes?(IPC::Data::WindowFlags::Background)
            program.z_index = -1
            @@windows.shift
          else
            program.z_index = 2
          end
          @@windows.push program
          @@windows.sort!

          socket.unbuffered_write IPC.response_message(program.wid).to_slice
        end
      when IPC::Data::MOVE_REQ_ID
        if (msg = FixedMessageReader(IPC::Data::MoveRequest).read(header, socket))
          if program = socket.program
            program.x = msg.x.clamp(0, framebuffer.width)
            program.y = msg.y.clamp(0, framebuffer.height)
            socket.unbuffered_write IPC.response_message(1).to_slice
          end
        end
      when IPC::Data::QUERY_ID
        if (msg = FixedMessageReader(IPC::Data::Query).read(header, socket))
          case msg.type
          when IPC::Data::QueryType::ScreenDim
            msg = IPC::DynamicWriter(8).write do |buffer|
              data = buffer.to_unsafe.as(Int32*)
              data[0] = framebuffer.width
              data[1] = framebuffer.height
            end
            socket.unbuffered_write msg.to_slice
          end
        end
      end
    end
  end

end

Wm::Server.init
Wm::Server.loop
