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

  def to_slice
    Slice(T).new(to_unsafe, N)
  end

  def []=(idx : Int, value : T)
    abort "setting out of bounds!" unless 0 <= idx && idx < N
    to_unsafe[idx] = value
  end

  def [](index : Int)
    abort "accessing out of bounds!" unless 0 <= idx && idx < N
    to_unsafe[idx]
  end

  def []?(index : Int)
    return nil unless 0 <= idx && idx < N
    to_unsafe[idx]
  end

  def size
    N
  end

  def each : Nil
    {% for i in 0...N %}
      yield self[{{i}}]
    {% end %}
  end
end
