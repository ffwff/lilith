require "socket"

server = IPCServer.new("test").not_nil!
Process.new "sockchd"
if socket = server.accept?
  STDERR.print "connected: ", socket.fd, "!\n"
  bytes = Bytes.new 128
  socket.unbuffered_read bytes
  print "rd: ", String.new(bytes), '\n'
end
