abstract struct OutputDriver
  abstract def putc(c : UInt8)

  def print(*args)
    args.each do |arg|
      arg.to_s self
    end
  end
end
