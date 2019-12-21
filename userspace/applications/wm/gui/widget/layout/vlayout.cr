class G::VLayout < G::Layout

  @placement_x = 0
  @has_stretch = false

  def add_widget(widget : G::Widget)
    if @has_stretch
      # calculate widths for stretches
      widgets_width = 0 
      n_stretch = 0
      @widgets.each do |w|
        if w.is_a?(G::Stretch)
          n_stretch += 1
        else
          widgets_width += w.width
        end
      end
      if widget.is_a?(G::Stretch)
        n_stretch += 1
      else
        widgets_width += widget.width
      end

      # place the widgets
      stretch_width = (@parent.not_nil!.width - widgets_width) // n_stretch
      placement_x = 0
      @widgets.each do |w|
        if w.is_a?(G::Stretch)
          placement_x += stretch_width
        else
          w.move placement_x, w.y
          placement_x += w.width
        end
      end

      unless widget.is_a?(G::Stretch)
        widget.move placement_x, widget.y
      end
      @widgets.push widget
    else
      if widget.is_a?(G::Stretch)
        @has_stretch = true
      else
        widget.move @placement_x, widget.y
        @placement_x += widget.width
      end
      @widgets.push widget
    end

  end

end
