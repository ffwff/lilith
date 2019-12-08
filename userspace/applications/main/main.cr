if LibC.read(STDIN.fd, LibC::String.null, 0) < 0
  LibC.open "/kbd", LibC::O_RDONLY
end
if LibC.write(STDOUT.fd, LibC::String.null, 0) < 0
  LibC.open "/con", LibC::O_WRONLY
end
if LibC.write(STDERR.fd, LibC::String.null, 0) < 0
  LibC.open "/serial", LibC::O_WRONLY
end

Process.new "wm",
  input: Process::Redirect::Inherit,
  output: Process::Redirect::Inherit,
  error: Process::Redirect::Inherit
