{% if flag?(:smp) %}
  struct Spinlock
    @value = Atomic(Int32).new 0

    private def lock
      i = 0
      while true
        _, changed = @value.compare_and_set(0, 1)
        return if changed
        if i == 10000
          Serial.puts "spinlock: unable to lock after 10000 iterations\n"
        end
        i += 1
      end
    end

    private def unlock
      @value.compare_and_set(1, 0)
    end

    def locked?
      @value.get != 0
    end

    def with(&block)
      lock
      yield
      unlock
    end
  end
{% else %}
  struct Spinlock
    def locked?
      false
    end

    def with(&block)
      yield
    end
  end
{% end %}
