module Indexable(T)
  def first
    self[0]
  end

  def first?
    self[0]?
  end

  def last
    self[self.size - 1]
  end

  def last?
    self[self.size - 1]?
  end
end
