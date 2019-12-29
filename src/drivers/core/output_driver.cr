module OutputDriver
  extend self

  def print(*args)
    args.each do |arg|
      arg.to_s self
    end
  end
end
