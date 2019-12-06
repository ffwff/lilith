require "./gui/lib"


module Bar
  extend self

  @@time_label : G::Label? = nil
  class_getter! time_label
  class_setter time_label

  @@window: G::Window? = nil
  class_getter! window
  class_setter window

  class Timer < G::Timer
    def self.new
      new 1
    end

    def on_tick
      time = Time.local
      Bar.time_label.text = time.to_s("%d/%m/%Y %H:%M:%S").not_nil!
      Bar.window.draw_event
    end
  end
end

app = G::Application.new
w, h = app.client.screen_resolution.not_nil!
window = G::Window.new(0, 0, w, 16)
app.main_widget = window
Bar.window = window

lbox = G::LayoutBox.new 0, 0, w, 10
window.main_widget = lbox

lbox.layout = G::VLayout.new
lbox.add_widget G::Label.new(0, 3, "lilith")
lbox.add_widget G::Stretch.new
Bar.time_label = G::Label.new(0, 3, "00/00/0000 00:00:00")
lbox.add_widget Bar.time_label

app.register_timer Bar::Timer.new

app.run
