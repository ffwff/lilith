require "./gui/lib"

app = G::Application.new
window = G::Window.new(0, 0, 400, 300)
decoration = G::WindowDecoration.new(window, "Test")
app.main_widget = window
app.run
