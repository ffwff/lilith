abstract class G::Layout

  @app : G::Application? = nil
  property app

  getter x, y, width, height, widgets
  def initialize(@x : Int32, @y : Int32, @width : Int32, @height : Int32)
    @widgets = [] of G::Widget
  end

  def self.new(widget : G::LayoutBox)
    layout = self.new widget.x, widget.y, widget.width, widget.height
    layout.app = widget.app
    layout
  end

end
