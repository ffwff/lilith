STDOUT.buffer_size = 0

module Adam
  extend self

  @@cwd = ""
  class_property cwd
end

def getline : String?
  buffer = uninitialized UInt8[128]
  return nil if (nread = STDIN.read(buffer.to_slice)) <= 0
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
      Adam.cwd = Dir.current.not_nil!
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
          error: Process::Redirect::Inherit)
      proc.wait if wait
    else
      print "unable to spawn ", cmd, '\n'
    end
  end
end

Adam.cwd = Dir.current.not_nil!
while true
  print Adam.cwd, "> "
  if line = getline
    interpret_line line
  end
end
