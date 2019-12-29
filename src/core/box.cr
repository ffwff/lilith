# :nodoc:
class Box(T)
  def initialize
    @object = uninitialized T
  end

  def initialize(@object : T)
  end

  def to_unsafe
    pointerof(@object)
  end

  def object=(@object)
  end
end
