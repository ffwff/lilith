if ARGV.size == 0
  dir = Dir.new(".")
else
  dir = Dir.new(ARGV[0])
end
if dir
  dir.each_child do |filename|
    puts filename
  end
else
  print PROGRAM_NAME, ": no such directory\n"
  exit 1
end
