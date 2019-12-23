struct Spinlock
  def locked?
    false
  end

  def with(&block)
    yield
  end
end
