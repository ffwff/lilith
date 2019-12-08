class G::Timer

  @last_tick = 0u64
  property last_tick

  @interval = 0
  getter interval

  def initialize(@interval)
  end

  def on_tick
  end

end
