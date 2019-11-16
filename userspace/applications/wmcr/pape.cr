require "./gui/lib"

if ARGV.size < 1
  print "usage: ", PROGRAM_NAME, " file\n"
  exit 1
end

app = G::Application.new
w, h = app.client.screen_resolution.not_nil!
window = G::Window.new(0, 0, w, h,
                       Wm::IPC::Data::WindowFlags::Background)
app.main_widget = window

window.setup_event
Painter.load_png ARGV[0], Bytes.new(window.bitmap.as(UInt8*), w * h * 4)

app.run
