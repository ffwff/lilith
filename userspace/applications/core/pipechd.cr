pipe = IO::Pipe.new("test", "r").unwrap!
bytes = Bytes.new 5
pipe.unbuffered_read bytes
puts String.new(bytes)
