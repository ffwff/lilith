require "./output_driver.cr"

private struct ConsoleInstance < OutputDriver

  @enabled = true
  property enabled

  @text_mode = true
  property text_mode

  def device
    if @text_mode
      VGA
    else
      Fbdev
    end
  end

  def putc(ch : UInt8)
    return unless @enabled
    device.putc ch
  end
  
  def putc(*args)
    return unless @enabled
    device.puts args
  end

  def newline
  end

  def width
    if @text_mode
      VGA_WIDTH
    else
      FbdevState.cwidth
    end
  end

  def height
    if @text_mode
      VGA_HEIGHT
    else
      FbdevState.cheight
    end
  end

end

Console = ConsoleInstance.new