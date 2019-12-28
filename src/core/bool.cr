# :nodoc:
struct Bool
  def to_unsafe
    self ? 1 : 0
  end

  def to_s(io)
    if self
      io.print "true"
    else
      io.print "false"
    end
  end
end
