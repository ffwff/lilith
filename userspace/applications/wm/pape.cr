require "./gui/lib"

if ARGV.size < 1
  print "usage: ", PROGRAM_NAME, " file\n"
  exit 1
end

module Pape
  extend self

  lib Data
    MAGIC = "pape-ipc"
    @[Packed]
    struct Message
      magic : UInt8[8]
      length : UInt16
    end
  end

  class Window < G::Window
    @path : String = ""
    property path

    @pipefd : IO::Pipe? = nil
    property pipefd

    def self.new(w : Int32, h : Int32, path : String, pipefd : IO::Pipe)
      window = new 0, 0, w, h, Wm::IPC::Data::WindowFlags::Background
      window.path = path
      window.pipefd = pipefd
      window
    end

    def mouse_event(ev : G::MouseEvent)
      @app.not_nil!.client << Wm::IPC.cursor_update_request_message(Wm::IPC::Data::CursorType::Default)
    end

    def draw_event
      Painter.load_png @path, bitmap!.to_bytes
      @app.not_nil!.send_redraw_message
    end

    def io_event(io : IO::FileDescriptor)
      case io
      when @pipefd.not_nil!
        header = uninitialized Data::Message
        io.unbuffered_read Bytes.new(pointerof(header).as(UInt8*), sizeof(Data::Message))
        if LibC.strncmp(header.magic.to_unsafe,
                        Data::MAGIC.to_unsafe,
                        Data::MAGIC.bytesize) != 0
          return 
        end
        bytes = Bytes.new(header.length)
        io.unbuffered_read bytes
        @path = String.new(bytes)
        draw_event
      end
    end
  end

  def create_header(size)
    header = Data::Message.new
    LibC.strncpy(header.magic.to_unsafe,
      Data::MAGIC.to_unsafe,
      Data::MAGIC.bytesize)
    header.length = size
    header
  end

end

arg0 = ARGV[0]

if IO::Pipe.exists?("pape")
  pipefd = IO::Pipe.new("pape", "rwa").unwrap!
  header = Pape.create_header(arg0.bytesize)
  pipefd.unbuffered_write Bytes.new(pointerof(header).as(UInt8*), sizeof(Pape::Data::Message))
  pipefd.unbuffered_write arg0.byte_slice
else
  pipefd = IO::Pipe.new("pape", "rwa").unwrap!

  app = G::Application.new
  w, h = app.client.screen_resolution.not_nil!
  window = Pape::Window.new(w, h, arg0, pipefd)
  app.main_widget = window
  app.watch_io pipefd

  app.run
end
