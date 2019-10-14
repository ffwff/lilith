i = 0
ARGV.each do |args|
  print args
  unless i == ARGV.size - 1
    print " "
  end
  i += 1
end
print "\n"
