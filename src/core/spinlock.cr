struct Spinlock

  @value = false

  private def compare_and_set(cmp, new)
    result = 0u64
    asm("cmpxchg $2, ($1)"
      : "={rax}"(result)
      : "r"(pointerof(@value)), "r"(new), "{rax}"(cmp)
      : "volatile", "memory")
    result == cmp.to_unsafe
  end

  def lock
    i = 0
    while i < 10000
      return true if compare_and_set(false, true)
      i += 1
    end
    Serial.puts "spinlock: unable to lock after 10000 iterations\n"
    false
  end

  def unlock
    compare_and_set(true, false)
  end

  def with(&block)
    return unless lock
    yield
    unlock
  end

end