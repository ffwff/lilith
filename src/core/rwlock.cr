struct RWLock
  @read_lock = Spinlock.new
  @global_lock = Spinlock.new
  @n_readers = 0

  def read(&block)
    @read_lock.with do
      @n_readers += 1
      if @n_reads == 1
        @global_lock.lock
      end
    end
    begin
      retval = yield
    ensure
      @read_lock.with do
        @n_readers -= 1
        if @n_reads == 0
          @global_lock.unlock
        end
      end
    end
    retval
  end

  def write(&block)
    @global_lock.with do
      yield
    end
  end
end
