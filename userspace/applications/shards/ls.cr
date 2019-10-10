if ARGV.size == 0
  dir = Dir.new(".")
else
  dir = Dir.new(ARGV[0])
end
dir.children.each do |filename|
  puts filename
end
