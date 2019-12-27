struct StaticArray(T, N)
  macro [](*args)
    %array = uninitialized StaticArray(typeof({{*args}}), {{args.size}})
    {% for arg, i in args %}
      %array.to_unsafe[{{i}}] = {{arg}}
    {% end %}
    %array
  end

  def to_unsafe : Pointer(T)
    pointerof(@buffer)
  end

  def []=(index : Int, value : T)
    abort "setting out of bounds!" unless 0 <= index < N
    to_unsafe[index] = value
  end

  def [](index : Int)
    abort "setting out of bounds!" unless 0 <= index < N
    to_unsafe[index]
  end

  def []?(index : Int)
    return nil if index > N
    to_unsafe[index]
  end

  def size
    N
  end

  def each : Nil
    {% for i in 0...N %}
      yield self[{{i}}]
    {% end %}
  end

  def to_s(io)
    io.print "StaticArray(", to_unsafe, " ", N, ")"
  end
end
