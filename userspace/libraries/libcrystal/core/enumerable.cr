module Enumerable(T)
  abstract def each(&block : T -> _)

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

  def all?
    each { |e| return false unless yield e }
    true
  end

  def any?(&block)
    each { |e| return true if yield e }
    false
  end
end
