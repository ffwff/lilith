STDOUT.buffer_size = 0

module Adam
  extend self

  @@cwd = ""
  class_property cwd
end

def getline : String
  buffer = uninitialized UInt8[128]
  if (nread = STDIN.read(buffer.to_slice)) <= 0
    exit 0
  end
  nread -= 1 # trim newline
  buffer[nread] = 0u8
  String.new(buffer.to_unsafe, nread)
end

def interpret_line(line)
  argv = line.split(' ', remove_empty: true)
  return unless argv.size > 0
  if argv[0] == "cd"
    if argv[1]?
      Dir.cd argv[1]
      Adam.cwd = Dir.current.unwrap!
    end
  else
    cmd = argv.shift.not_nil!
    wait = true
    if argv.last? == "&"
      argv.pop
      wait = false
    end
    if proc = Process.new(cmd, argv,
         input: Process::Redirect::Inherit,
         output: Process::Redirect::Inherit,
         error: Process::Redirect::Inherit).ok?
      proc.wait if wait
    else
      print "unable to spawn ", cmd, '\n'
    end
  end
end

Adam.cwd = Dir.current.unwrap!
while true
  print Adam.cwd, "> "
  interpret_line getline
end
