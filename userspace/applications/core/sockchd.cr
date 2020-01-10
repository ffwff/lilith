require "socket"

server = IPCSocket.new("test").unwrap!
server.puts "test"
IO::Select.wait server, UInt32::MAX
bytes = Bytes.new 128
print "client read: ", server.unbuffered_read(bytes), '\n'
print "client rd: ", String.new(bytes), '\n'
