struct Spinlock

  @value = Atomic(Int32).new 0

  def lock
    i = 0
    while i < 10000
      _, changed = @value.compare_and_set(0, 1)
      return true if changed
      i += 1
    end
    Serial.puts "spinlock: unable to lock after 10000 iterations\n"
    false
  end

  def lockable?
    @value.get == 0
  end

  def unlock
    @value.compare_and_set(1, 0)
  end

  def with(&block)
    return unless lock
    yield
    unlock
  end

end