class Box(T)

  def initialize
    @object = uninitialized T
  end

  def initialize(@object : T)
  end

  def to_unsafe
    self.as(T*)
  end

  def object
    self.as(T*).value
  end

  def object=(@object)
  end

end
