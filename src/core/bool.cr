struct Bool
  def to_unsafe
    self ? 1 : 0
  end

  def to_s(io)
    if self
      io.puts "true"
    else
      io.puts "false"
    end
  end
end
