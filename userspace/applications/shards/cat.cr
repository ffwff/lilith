if ARGV.size < 1
  print "usage: ", PROGRAM_NAME, " file\n"
  exit 1
end

file = File.new(ARGV[0]).not_nil!
buffer = uninitialized UInt8[4096]
while (size = file.read(buffer.to_slice)) > 0
  STDOUT.write buffer.to_slice[0, size]
end
