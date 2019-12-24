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

  @[Flags]
  enum KeyboardModifiers : Int32
    ShiftL = 1 << 0
    ShiftR = 1 << 1
    CtrlL  = 1 << 2
    CtrlR  = 1 << 3
    GuiL   = 1 << 4
  end

  @[Packed]
  struct KeyboardPacket
    ch : Int32
    modifiers : KeyboardModifiers
  end
end

module Wm::Server
  extend self

  CURSOR_FILE = "/hd0/share/cursors/cursor.png"
  CURMOVE_FILE = "/hd0/share/cursors/move.png"

  abstract class Window
    @x : Int32 = 0
    @y : Int32 = 0
    @z_index : Int32 = 0
    property x, y, z_index

    @bitmap : Painter::Bitmap? = nil
    getter! bitmap
    setter bitmap

    def bitmap?
      @bitmap
    end

    abstract def render(bitmap : Painter::Bitmap)

    # render a portion of the window, clipped by a dirty rect
    # the dirty rect must intersect the window, and must be absolutely positioned
    abstract def render_cropped(bitmap : Painter::Bitmap, rect : Wm::Server::DirtyRect)

    def <=>(other)
      @z_index <=> other.z_index
    end

    def contains_point?(x : Int, y : Int)
      bitmap = @bitmap.not_nil!
      @x <= x <= (@x + bitmap.width) &&
        @y <= y <= (@y + bitmap.height)
    end
  end

  class Background < Window
    def initialize(@color : UInt32)
      @z_index = -1
    end

    def render(buffer : Painter::Bitmap)
      Painter.blit_u32(buffer.to_unsafe, @color, Server.framebuffer.width.to_usize * Server.framebuffer.height.to_usize)
    end

    def render_cropped(buffer : Painter::Bitmap, rect : Wm::Server::DirtyRect)
      Painter.blit_rect buffer, rect.width, rect.height, rect.x, rect.y, @color
    end

    def contains_point?(x : Int, y : Int)
      true
    end
  end

  class Cursor < Window
    @cursor_def : Painter::Bitmap
    @cursor_move : Painter::Bitmap

    def initialize
      @cursor_def = Painter.load_png(CURSOR_FILE).not_nil!
      @cursor_move = Painter.load_png(CURMOVE_FILE).not_nil!
      @bitmap = @cursor_def
      @z_index = Int32::MAX
    end

    def render(buffer : Painter::Bitmap)
      Painter.blit_img buffer, bitmap.not_nil!, @x, @y, true
    end

    def render_cropped(buffer : Painter::Bitmap, rect : Wm::Server::DirtyRect)
      Painter.blit_img buffer, bitmap.not_nil!, @x, @y, true
    end

    def respond(file)
      packet = LibC::MousePacket.new
      file.read(Bytes.new(pointerof(packet).as(UInt8*), sizeof(LibC::MousePacket)))
      old_x, old_y = @x, @y
      if packet.x != 0
        delta_x = packet.x
        @x = @x + delta_x
        @x = @x.clamp(0, Server.framebuffer.width)
      end
      if packet.y != 0
        delta_y = -packet.y
        @y = @y + delta_y
        @y = @y.clamp(0, Server.framebuffer.height)
      end
      if packet.x != 0 || packet.y != 0
        dx = Math.min(@x, old_x)
        dy = Math.min(@y, old_y)
        dw = Math.max(@x, old_x) + bitmap.width - dx
        dh = Math.max(@y, old_y) + bitmap.height - dy
        Wm::Server.make_dirty dx, dy, dw, dh
      end
      packet
    end

    def change_type(type)
      @bitmap = case type
                when IPC::Data::CursorType::Default
                  @cursor_def
                when IPC::Data::CursorType::Move
                  @cursor_move
                else
                  @cursor_def
                end
    end
  end

  class Program < Window
    class Socket < IO::FileDescriptor
      @program : Program? = nil
      property program

      def initialize(@fd)
        self.buffer_size = 0
      end

      def send_update_message
        program = @program.not_nil!
        unbuffered_write Wm::IPC.window_update_message(program.x, program.y, program.bitmap.not_nil!.width, program.bitmap.not_nil!.height).to_slice
      end
    end

    @socket : Program::Socket
    @wid : Int32
    @bitmap_file : File

    getter socket, wid, bitmap, alpha

    def initialize(@socket, @x, @y, width, height, @alpha : Bool)
      @wid = Server.next_wid
      @bitmap_file = File.new("/tmp/wm-bm:" + @wid.to_s, "rw").not_nil!
      @bitmap_file.truncate width * height * 4
      @bitmap = Painter::Bitmap.new(width, height, @bitmap_file.map_to_memory(prot: LibC::MmapProt::Read).as(UInt32*))
    end

    def render(buffer : Painter::Bitmap)
      Painter.blit_img buffer, bitmap.not_nil!, @x, @y, @alpha
    end

    def render_cropped(buffer : Painter::Bitmap, rect : Wm::Server::DirtyRect)
      relx, rely, relw, relh = rect.translate_relative @x, @y, bitmap.not_nil!.width, bitmap.not_nil!.height
      Painter.blit_img_cropped buffer, bitmap.not_nil!,
        relw, relh, relx, rely,
        @x + relx, @y + rely, @alpha
    end

    def close
      Wm::Server.selector.delete @socket
      @socket.close
      @bitmap.not_nil!.to_unsafe.unmap_from_memory
      @bitmap_file.close
      File.remove("/tmp/wm-bm:" + @wid.to_s)
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

  struct DirtyRect
    getter x, y, width, height

    def initialize(@x : Int32, @y : Int32, @width : Int32, @height : Int32)
    end

    def window_in_rect?(win : Window)
      return false if win.bitmap?.nil?
      @x <= win.x && (win.x + win.bitmap.not_nil!.width) <= (@x + @width) &&
        @y <= win.y && (win.y + win.bitmap.not_nil!.height) <= (@y + @height)
    end

    def intersects_window?(win : Window)
      return false if win.bitmap?.nil?
      bitmap = win.bitmap.not_nil!
      intersects_x = !(@x + @width <= win.x || win.x + bitmap.width <= @x)
      intersects_y = !(@y + @height <= win.y || win.y + bitmap.height <= @y)
      intersects_x && intersects_y
    end

    def translate_relative(dx : Int, dy : Int, dw : Int, dh : Int)
      # rect.x < @x ? (rect.x + rect.width) - @x : rect.x - @x,
      relx = (@x - dx).clamp(0, dw)
      rely = (@y - dy).clamp(0, dh)
      relw = ((@x + @width) - dx).clamp(0, dw) - relx
      relh = ((@y + @height) - dy).clamp(0, dh) - rely
      {relx, rely, relw, relh}
    end
  end

  # dirty rects
  @@dirty_rects : Array(DirtyRect)? = nil
  class_getter! dirty_rects
  @@largest_dirty_width = 0
  @@largest_dirty_height = 0
  @@redraw_all = false

  def make_dirty(x, y, width, height)
    return if @@redraw_all
    @@largest_dirty_width = Math.max(@@largest_dirty_width, width)
    @@largest_dirty_height = Math.max(@@largest_dirty_height, height)
    if @@largest_dirty_width == framebuffer.width &&
       @@largest_dirty_height == framebuffer.height
      @@redraw_all = true
      return
    end
    dirty_rects.push DirtyRect.new(x, y, width, height)
  end

  def init
    unless (@@fb = File.new("/fb0", "r"))
      abort "unable to open /fb0"
    end
    @@dirty_rects = Array(DirtyRect).new
    @@redraw_all = true
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
    Process.new "desktop",
      input: Process::Redirect::Inherit,
      output: Process::Redirect::Inherit,
      error: Process::Redirect::Inherit
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
      if @@redraw_all
        @@windows.each do |window|
          window.render backbuffer
        end
        LibC.memcpy framebuffer.to_unsafe, backbuffer.to_unsafe,
          (framebuffer.width.to_usize * framebuffer.height.to_usize * 4)
        dirty_rects.clear
        @@largest_dirty_width = 0
        @@largest_dirty_height = 0
        @@redraw_all = false
      elsif dirty_rects.size > 0
        dirty_rects.each do |rect|
          # Painter.blit_rect Wm::Server.framebuffer, rect.width, rect.height, rect.x, rect.y, 0xff0000
          @@windows.each do |window|
            if rect.window_in_rect?(window)
              window.render backbuffer
            elsif rect.intersects_window?(window)
              window.render_cropped backbuffer, rect
            end
          end
        end
        LibC.memcpy framebuffer.to_unsafe, backbuffer.to_unsafe,
          (framebuffer.width.to_usize * framebuffer.height.to_usize * 4)
        dirty_rects.clear
        @@largest_dirty_width = 0
        @@largest_dirty_height = 0
      end
    end
  end

  @@last_kbd_modifiers = IPC::Data::KeyboardEventModifiers::None
  def respond_kbd
    packet = uninitialized LibC::KeyboardPacket
    if kbd.unbuffered_read(Bytes.new(pointerof(packet).as(UInt8*), sizeof(LibC::KeyboardPacket))) \
         != sizeof(LibC::KeyboardPacket)
      return
    end
    modifiers = IPC::Data::KeyboardEventModifiers.new(packet.modifiers.value)
    @@last_kbd_modifiers = modifiers
    if focused = @@focused
      focused.socket.unbuffered_write IPC.kbd_event_message(packet.ch, modifiers).to_slice
      if modifiers.includes?(IPC::Data::KeyboardEventModifiers::GuiL)
        focused.socket.unbuffered_write IPC.mouse_event_message(@@last_mouse_x, @@last_mouse_y, IPC::Data::MouseEventModifiers::None, 0).to_slice
      end
    end
  end

  @@last_mouse_x = 0u32
  @@last_mouse_y = 0u32
  @@last_mouse_modifiers = IPC::Data::MouseEventModifiers::None
  def respond_mouse
    packet = cursor.respond mouse
    @@last_mouse_x = packet.x
    @@last_mouse_y = packet.y

    modifiers = IPC::Data::MouseEventModifiers::None
    if packet.attributes.includes?(LibC::MouseAttributes::LeftButton)
      modifiers |= IPC::Data::MouseEventModifiers::LeftButton
    end
    if packet.attributes.includes?(LibC::MouseAttributes::RightButton)
      modifiers |= IPC::Data::MouseEventModifiers::RightButton
    end
    if packet.attributes.includes?(LibC::MouseAttributes::MiddleButton)
      modifiers |= IPC::Data::MouseEventModifiers::MiddleButton
    end
    @@last_mouse_modifiers = modifiers

    if (focused = @@focused) && focused.contains_point?(cursor.x, cursor.y)
      focused.socket.unbuffered_write IPC.mouse_event_message(cursor.x, cursor.y, modifiers, packet.scroll_delta).to_slice
      return
    end
    if modifiers.includes?(IPC::Data::MouseEventModifiers::LeftButton)
      @@windows.reverse_each do |win|
        if win.is_a?(Program)
          win = win.as(Program)
          if win.contains_point?(cursor.x, cursor.y) && win.z_index != -1
            break if win == @@focused
            cursor.change_type Wm::IPC::Data::CursorType::Default
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
            unless @@windows[0].is_a?(Background)
              socket.unbuffered_write IPC.response_message(-1).to_slice
              next
            end
          end

          if focused = @@focused
            focused.socket.unbuffered_write IPC.refocus_event_message(focused.wid, 0).to_slice
          end
          socket.program = program = Program.new(socket, msg.x, msg.y,
            msg.width, msg.height,
            msg.flags.includes?(IPC::Data::WindowFlags::Alpha))
          @@focused = program
          if msg.flags.includes?(IPC::Data::WindowFlags::Background)
            program.z_index = -1
            @@windows.shift
          else
            program.z_index = 2
          end
          @@windows.push program
          @@windows.sort!
          make_dirty msg.x, msg.y, msg.width, msg.height

          socket.unbuffered_write IPC.response_message(program.wid).to_slice
        end
      when IPC::Data::MOVE_REQ_ID
        if (msg = FixedMessageReader(IPC::Data::MoveRequest).read(header, socket))
          if program = socket.program
            old_x, old_y = program.x, program.y
            if msg.relative == 1u8
              program.x = (program.x + msg.x).clamp(0, framebuffer.width)
              program.y = (program.y + msg.y).clamp(0, framebuffer.height)
            else
              program.x = msg.x.clamp(0, framebuffer.width)
              program.y = msg.y.clamp(0, framebuffer.height)
            end
            if bitmap = program.bitmap
              dx = Math.min(old_x, program.x)
              dy = Math.min(old_y, program.y)
              dw = Math.max(old_x, program.x) + bitmap.width - dx
              dh = Math.max(old_y, program.y) + bitmap.height - dy
              make_dirty dx, dy, dw, dh
              # dw = max(old_x+bwidth,program.x+bwidth)-dx
            end
            socket.send_update_message
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
      when IPC::Data::REDRAW_REQ_ID
        if (msg = FixedMessageReader(IPC::Data::RedrawRequest).read(header, socket))
          if msg.x == -1 && msg.y == -1 && msg.width == -1 && msg.height == -1
            if program = socket.program
              make_dirty program.x, program.y, program.bitmap.not_nil!.width, program.bitmap.not_nil!.height
              socket.unbuffered_write IPC.response_message(1).to_slice
            else
              socket.unbuffered_write IPC.response_message(0).to_slice
            end
          else
            make_dirty msg.x, msg.y, msg.width, msg.height
            socket.unbuffered_write IPC.response_message(1).to_slice
          end
        end
      when IPC::Data::WINDOW_CLOSE_ID
        if program = socket.program
          socket.unbuffered_write IPC.response_message(1).to_slice
          make_dirty program.x, program.y, program.bitmap.not_nil!.width, program.bitmap.not_nil!.height
          if @@focused == program
            @@focused = nil
          end
          program.close
          @@windows.delete program
        else
          socket.unbuffered_write IPC.response_message(-1).to_slice
        end
      when IPC::Data::CURSOR_UPDATE_REQ_ID
        if (msg = FixedMessageReader(IPC::Data::CursorUpdateRequest).read(header, socket))
          cursor.change_type msg.type
          socket.unbuffered_write IPC.response_message(1).to_slice
        end
      end
    end
  end
end

Wm::Server.init
Wm::Server.loop
