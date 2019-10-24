pipe = IO::Pipe.new("test", "w").not_nil!
pipe.unbuffered_write "helloworld".byte_slice
Process.new "pipechd"
