require "socket"

server = IPCSocket.new("test").not_nil!
server.unbuffered_write "test".byte_slice
