require "./gui/lib"

module FileMgr
  extend self

  @@dir_image : Painter::Bitmap? = nil
  class_getter! dir_image

  @@file_image : Painter::Bitmap? = nil
  class_getter! file_image

  @@cwd = ""
  class_property cwd

  @@layout : G::Layout? = nil
  class_getter! layout

  class EntryFig < G::Figure
    def self.new(name, is_dir)
      new 0, 0, is_dir ? FileMgr.dir_image : FileMgr.file_image, name
    end

    @last_clicked = 0u64
    @double_clicks = 0
    MAX_DOUBLE_CLICK = 1
    def mouse_event(ev : G::MouseEvent)
      if ev.left_clicked?
        current = Time.unix
        if (current - @last_clicked) <= MAX_DOUBLE_CLICK || @last_clicked == 0
          @double_clicks += 1
          if @double_clicks == 2
            @double_clicks = 0
            Dir.cd @text.not_nil!
            FileMgr.load_dir
            app.redraw
          end
        else
          @double_clicks = 1
        end
        @last_clicked = current
      end
    end
  end

  def load_images
    @@dir_image = Painter.load_png("/drv/share/icons/folder.png").not_nil!
    @@file_image = Painter.load_png("/drv/share/icons/file.png").not_nil!
  end

  def run
    load_images

    app = G::Application.new
    window = G::Window.new(30, 30, 400, 300)
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
        File.open(child) do |file|
          layout.add_widget EntryFig.new(child, file.attributes.includes?(LibC::FileAttributes::Directory))
        end
      end
    end
    layout.resize_to_content
  end
end

FileMgr.run
