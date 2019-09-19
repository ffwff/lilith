module Time
  extend self
  
  @@stamp = 0u64
  def stamp; @@stamp; end
  def stamp=(@@stamp); end
  
end
