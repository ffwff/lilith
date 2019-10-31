require "./gui/lib"

app = G::Application.new
app.main_widget = G::Window.new(0, 0, 400, 300)
app.run
