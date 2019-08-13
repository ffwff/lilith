require "./output_driver.cr"

private struct ConsoleInstance < OutputDriver

  @device : OutputDriver = VGA
  property device

  def putc(ch : UInt8)
    @device.putc ch
  end

  def putc(*args)
    @device.puts args
  end

  def newline
    # @device.newline
  end

end

Console = ConsoleInstance.new