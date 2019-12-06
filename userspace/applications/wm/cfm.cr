require "./gui/lib"

app = G::Application.new
window = G::Window.new(0, 0, 400, 300)
app.main_widget = window

decoration = G::WindowDecoration.new(window, "fm")

sbox = G::ScrollBox.new 0, 0, window.width, window.height
decoration.main_widget = sbox

lbox = G::LayoutBox.new 0, 0, window.width, window.height
sbox.main_widget = lbox

dir_image = Painter.load_png("/hd0/share/icons/folder.png").not_nil!

lbox.layout = G::PLayout.new
50.times do
  lbox.add_widget G::Figure.new(0, 0, dir_image, "help")
end
lbox.resize_to_content

app.run
