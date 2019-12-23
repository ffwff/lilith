abstract class G::Layout
  @app : G::Application? = nil
  property app

  @parent : G::LayoutBox? = nil
  property parent

  getter widgets

  def initialize
    @widgets = [] of G::Widget
  end

  def resize_to_content
  end

  def clear
    @widgets.clear
  end
end
