STDOUT.buffer_size = 0

if LibC.read(STDIN.fd, LibC::String.null, 0) < 0
  LibC.open "/kbd", O_RDONLY
end
if LibC.write(STDOUT.fd, LibC::String.null, 0) < 0
  LibC.open "/con", O_WRONLY
end
if LibC.write(STDERR.fd, LibC::String.null, 0) < 0
  LibC.open "/serial", O_WRONLY
end

cwd = Dir.current

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
      cwd = Dir.current
    end
  else
    cmd = argv.shift.not_nil!
    if proc = Process.new(cmd, argv)
      proc.wait
    else
      print "unable to spawn ", cmd, '\n'
    end
  end
end

while true
  print cwd, "> "
  if line = getline
    interpret_line line
  end
end
