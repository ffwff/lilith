struct Bool
  def to_s(io)
    if self
      io.puts "true"
    else
      io.puts "false"
    end
  end
end
