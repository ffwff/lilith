if ARGV.size < 1
  print "usage: ", PROGRAM_NAME, " file\n"
  exit 1
end

file = File.new(ARGV[0], "w").not_nil!
