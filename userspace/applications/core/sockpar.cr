require "socket"

server = IPCServer.new("test").not_nil!
while socket = server.accept?
  puts "connected!"
end
