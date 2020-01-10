pipe = IO::Pipe.new("test", "w").unwrap!
pipe.unbuffered_write "helloworld".byte_slice
Process.new "pipechd"
