class G::Window < G::Widget

  getter x, y, width, height

  @wm_window : Wm::Window? = nil
  getter wm_window

  def initialize(@x : Int32, @y : Int32,
                 @width : Int32, @height : Int32)
  end

  def bitmap
    @wm_window.not_nil!.bitmap
  end

  def setup_event
    @wm_window = app.client.create_window(@x, @y, @width, @height).not_nil!
  end

end
