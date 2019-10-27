require "socket"

server = IPCServer.new("test").not_nil!
Process.new("sockchd",
  input: Process::Redirect::Inherit,
  output: Process::Redirect::Inherit,
  error: Process::Redirect::Inherit)
if socket = server.accept?
  print "connected: ", socket.fd, "!\n"
  bytes = Bytes.new 128
  print "read: ", socket.unbuffered_read(bytes), '\n'
  print "rd: ", String.new(bytes), '\n'
  socket.puts "hello"
end
