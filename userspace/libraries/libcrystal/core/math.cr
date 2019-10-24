module Math
  extend self

  def max(x, y)
    x > y ? x : y
  end

  def min(x, y)
    x > y ? y : x
  end

  def log2(n)
    Intrinsics.counttrailing32(n.to_i32, true) + 1
  end
end
