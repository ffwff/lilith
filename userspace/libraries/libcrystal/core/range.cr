struct Range(B, E)
  def begin
    @begin
  end

  def end
    @end
  end

  getter exclusive

  def size
    @end - @begin
  end

  def initialize(@begin : B, @end : E, @exclusive : Bool = false)
  end

  def each
    if exclusive
      i = @begin
      while i <= @end
        yield i
      end
    else
      i = @begin
      while i < @end
        yield i
      end
    end
  end
end
