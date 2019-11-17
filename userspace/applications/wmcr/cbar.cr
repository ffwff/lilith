require "./gui/lib"

app = G::Application.new
w, h = app.client.screen_resolution.not_nil!
window = G::Window.new(0, 0, w, 10)
app.main_widget = window

lbox = G::LayoutBox.new 0, 0, w, 10
window.main_widget = lbox
lbox.layout = G::VLayout.new lbox
lbox.add_widget G::Label.new(0, 0, "lilith")
lbox.add_widget G::Stretch.new
lbox.add_widget G::Label.new(0, 0, "aaaaa")

app.run
