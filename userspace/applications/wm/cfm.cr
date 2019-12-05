require "./gui/lib"

app = G::Application.new
window = G::Window.new(0, 0, 400, 300)
app.main_widget = window

decoration = G::WindowDecoration.new(window, "fm")

lbox = G::LayoutBox.new 0, 0, window.width, window.height
decoration.main_widget = lbox

lbox.layout = G::VLayout.new lbox
lbox.add_widget G::Figure.new(0, 0, "/hd0/share/icons/folder.png", "shigure")

app.run
