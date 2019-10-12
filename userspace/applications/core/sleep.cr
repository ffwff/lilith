if ARGV.size < 1
  print "usage: ", PROGRAM_NAME, " seconds\n"
  exit 1
end
sleep ARGV[0].to_i
