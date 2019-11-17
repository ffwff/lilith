class G::VLayout < G::Layout

  @placement_x = 0

  def add_widget(widget : G::Widget)
    widget.move @placement_x, widget.y
    @placement_x += widget.width
    @widgets.push widget
  end

end
