require "./gui/lib"

if ARGV.size < 1
  print "usage: ", PROGRAM_NAME, " file\n"
  exit 1
end

class PapeWindow < G::Window
  @path : String = ""
  property path

  def self.new(w : Int32, h : Int32, path : String)
    window = new 0, 0, w, h, Wm::IPC::Data::WindowFlags::Background
    window.path = path
    window
  end

  def mouse_event(ev : G::MouseEvent)
    @app.not_nil!.client << Wm::IPC.cursor_update_request_message(Wm::IPC::Data::CursorType::Default)
  end

  def draw_event
    Painter.load_png @path, bitmap!.to_bytes
    @app.not_nil!.send_redraw_message
  end
end

app = G::Application.new
w, h = app.client.screen_resolution.not_nil!
window = PapeWindow.new(w, h, ARGV[0])
app.main_widget = window

app.run
