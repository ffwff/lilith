module Enumerable(T)
  def each_with_index(&block)
    i = 0
    each do |obj|
      yield obj, i
      i += 1
    end
  end

  def index(obj)
    i = 0
    each do |obj1|
      return i if obj == obj1
      i += 1
    end
  end
end
