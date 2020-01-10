struct Result(T, E)
  def initialize(@data : (T | E))
  end

  def is_ok?
    @data.is_a?(T)
  end

  def is_err?
    @data.is_a?(E)
  end

  def unwrap!(msg = "Result.unwrap() called on error")
    if @data.is_a?(T)
      @data.as!(T)
    else
      abort msg
    end
  end

  def unwrap_err!(msg = "Result.unwrap_err() called on ok")
    if @data.is_a?(E)
      @data.as!(E)
    else
      abort msg
    end
  end

  def ok?
    @data.as?(T)
  end

  def err?
    @data.as?(E)
  end
end

macro try?(result)
  {{ result }}.ok? || return {{ result }}.err?
end
