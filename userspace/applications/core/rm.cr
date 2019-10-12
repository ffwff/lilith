if ARGV.size < 1
  print "usage: ", PROGRAM_NAME, " file\n"
  exit 1
end

# FIXME: better way to do this pls
lib LibC
  fun remove(filename : LibC::UString) : LibC::Int
end
LibC.remove ARGV[0].to_unsafe
