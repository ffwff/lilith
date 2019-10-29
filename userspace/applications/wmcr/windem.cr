require "./gui/lib"

app = G::Application.new
main_window = G::Window.new(0, 0, 400, 300)
app.main_widget = main_window
app.run
