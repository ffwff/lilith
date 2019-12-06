class G::PLayout < G::Layout

  @placement_x = 0
  @placement_y = 0
  @line_height = 0

  def add_widget(widget : G::Widget)
    parent = @parent.not_nil!
    # STDERR.print "w: ", parent.width, "\n"
    if (@placement_x + widget.width) >= parent.width
      @placement_x = 0
      @placement_y += @line_height
      @line_height = 0
    else
      widget.move @placement_x, @placement_y
      @placement_x += widget.width
      @line_height = Math.max(@line_height, widget.height)
    end
    @widgets.push widget
  end

  def resize_to_content
    parent = @parent.not_nil!
    new_width = parent.width
    x = 0
    line_height = 0
    new_height = 0
    @widgets.each do |widget|
      if (x + widget.width) >= parent.width
        x = 0
        new_height += line_height
        line_height = 0
      else
        x += widget.width
        line_height = Math.max(line_height, widget.height)
      end
    end
    parent.resize new_width, new_height
  end

end
