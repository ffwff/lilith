require "./gui/lib"

module FileMgr
  extend self

  @@dir_image : Painter::Image? = nil
  class_getter! dir_image

  @@cwd = ""
  class_property cwd

  @@layout : G::Layout? = nil
  class_getter! layout
    
  class EntryFig < G::Figure
    def self.new(name)
      new 0, 0, FileMgr.dir_image, name
    end

    def mouse_event(ev : G::MouseEvent)
      if ev.left_clicked?
        Dir.cd @text.not_nil!
        FileMgr.load_dir
        app.redraw
      end
    end
  end

  def load_images
    @@dir_image = Painter.load_png("/hd0/share/icons/folder.png").not_nil!
  end

  def run
    load_images

    app = G::Application.new
    window = G::Window.new(0, 0, 400, 300)
    app.main_widget = window

    decoration = G::WindowDecoration.new(window, "fm")

    sbox = G::ScrollBox.new 0, 0, window.width, window.height
    decoration.main_widget = sbox

    lbox = G::LayoutBox.new 0, 0, window.width, window.height
    sbox.main_widget = lbox

    @@layout = lbox.layout = G::PLayout.new
    load_dir

    app.run
  end

  def load_dir
    @@cwd = Dir.current
    layout.clear
    Dir.open(".") do |dir|
      dir.each_child do |child|
        layout.add_widget EntryFig.new(child)
      end
    end
    layout.resize_to_content    
  end
end

FileMgr.run
