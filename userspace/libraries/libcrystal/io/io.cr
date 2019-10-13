abstract class IO
  abstract def read(slice : Bytes)
  abstract def write(slice : Bytes)

  def <<(obj) : self
    obj.to_s self
    self
  end

  def puts : Nil
    self << '\n'
  end

  def puts(obj) : Nil
    self << obj
    puts
  end

  def puts(*objects : _) : Nil
    objects.each do |obj|
      puts obj
    end
    nil
  end

  def print(*objects : _) : Nil
    objects.each do |obj|
      self << obj
    end
    nil
  end

end
