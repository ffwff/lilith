struct Result(T, E)

  def initialize(@data : (T | E))
  end

  
  def ok?
    case @data
    when T
      true
    else
      false
    end
  end

  def err?
    case @data
    when E
      true
    else
      false
    end
  end

  def unwrap(msg = "Result.unwrap() called on error")
    case @data
    when T
      @data.as(T)
    else
      abort msg
    end
  end

  def unwrap_err(msg = "Result.unwrap() called on ok")
    case @data
    when E
      @data.as(E)
    else
      abort msg
    end
  end

  def ok
    case @data
    when T
      @data.as(T)
    else
      nil
    end
  end

  def err
    case @data
    when E
      @data.as(E)
    else
      nil
    end
  end

end

macro try?(result)
  {{ result }}.ok || return {{ result }}.err
end

