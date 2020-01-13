if ARGV.size < 1
  print "usage: ", PROGRAM_NAME, " file\n"
  exit 1
end

File.new(ARGV[0], "w")
