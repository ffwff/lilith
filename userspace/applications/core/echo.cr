ARGV.each_with_index do |args, idx|
  print args
  unless idx == ARGV.size - 1
    print " "
  end
end
print "\n"
