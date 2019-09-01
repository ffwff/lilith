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
  
  def puts(args)
    return unless @enabled
    device.puts args
  end

  def newline
  end

  def width
    if @text_mode
      VGA_WIDTH
    else
      width = 0
      FbdevState.lock do |state|
        width = state.cwidth
      end
      width
    end
  end

  def height
    if @text_mode
      VGA_HEIGHT
    else
      height = 0
      FbdevState.lock do |state|
        height = state.cheight
      end
      height
    end
  end

  def locked?
    if @text_mode
      VgaState.locked?
    else
      FbdevState.locked?
    end
  end

end

Console = ConsoleInstance.new