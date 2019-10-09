abstract class IO
  # Argument to a `seek` operation.
  enum Seek
    # Seeks to an absolute location
    Set = 0

    # Seeks to a location relative to the current location
    # in the stream
    Current = 1

    # Seeks to a location relative to the end of the stream
    # (you probably want a negative value for the amount)
    End = 2
  end

  # Reads at most *slice.size* bytes from this `IO` into *slice*.
  # Returns the number of bytes read, which is 0 if and only if there is no
  # more data to read (so checking for 0 is the way to detect end of file).
  #
  # ```
  # io = IO::Memory.new "hello"
  # slice = Bytes.new(4)
  # io.read(slice) # => 4
  # slice          # => Bytes[104, 101, 108, 108]
  # io.read(slice) # => 1
  # slice          # => Bytes[111, 101, 108, 108]
  # io.read(slice) # => 0
  # ```
  abstract def read(slice : Bytes)

  # Writes the contents of *slice* into this `IO`.
  #
  # ```
  # io = IO::Memory.new
  # slice = Bytes.new(4) { |i| ('a'.ord + i).to_u8 }
  # io.write(slice)
  # io.to_s # => "abcd"
  # ```
  abstract def write(slice : Bytes) : Nil

  # Closes this `IO`.
  #
  # `IO` defines this is a no-op method, but including types may override.
  def close
  end

  # Returns `true` if this `IO` is closed.
  #
  # `IO` defines returns `false`, but including types may override.
  def closed?
    false
  end

  # Flushes buffered data, if any.
  #
  # `IO` defines this is a no-op method, but including types may override.
  def flush
  end
  
  # Writes the given object into this `IO`.
  # This ends up calling `to_s(io)` on the object.
  #
  # ```
  # io = IO::Memory.new
  # io << 1
  # io << '-'
  # io << "Crystal"
  # io.to_s # => "1-Crystal"
  # ```
  def <<(obj) : self
    obj.to_s self
    self
  end

  # Same as `<<`.
  #
  # ```
  # io = IO::Memory.new
  # io.print 1
  # io.print '-'
  # io.print "Crystal"
  # io.to_s # => "1-Crystal"
  # ```
  def print(obj) : Nil
    self << obj
    nil
  end

  # Writes the given objects into this `IO` by invoking `to_s(io)`
  # on each of the objects.
  #
  # ```
  # io = IO::Memory.new
  # io.print 1, '-', "Crystal"
  # io.to_s # => "1-Crystal"
  # ```
  def print(*objects : _) : Nil
    objects.each do |obj|
      print obj
    end
    nil
  end

  # Writes the given string to this `IO` followed by a newline character
  # unless the string already ends with one.
  #
  # ```
  # io = IO::Memory.new
  # io.puts "hello\n"
  # io.puts "world"
  # io.to_s # => "hello\nworld\n"
  # ```
  def puts(string : String) : Nil
    self << string
    puts unless string.ends_with?('\n')
    nil
  end

  # Writes the given object to this `IO` followed by a newline character.
  #
  # ```
  # io = IO::Memory.new
  # io.puts 1
  # io.puts "Crystal"
  # io.to_s # => "1\nCrystal\n"
  # ```
  def puts(obj) : Nil
    self << obj
    puts
  end

  # Writes a newline character.
  #
  # ```
  # io = IO::Memory.new
  # io.puts
  # io.to_s # => "\n"
  # ```
  def puts : Nil
    print '\n'
    nil
  end

  # Writes the given objects, each followed by a newline character.
  #
  # ```
  # io = IO::Memory.new
  # io.puts 1, '-', "Crystal"
  # io.to_s # => "1\n-\nCrystal\n"
  # ```
  def puts(*objects : _) : Nil
    objects.each do |obj|
      puts obj
    end
    nil
  end

  # Writes a single byte into this `IO`.
  #
  # ```
  # io = IO::Memory.new
  # io.write_byte 97_u8
  # io.to_s # => "a"
  # ```
  def write_byte(byte : UInt8)
    x = byte
    write Slice.new(pointerof(x), 1)
  end

  # Reads a single byte from this `IO`. Returns `nil` if there is no more
  # data to read.
  #
  # ```
  # io = IO::Memory.new "a"
  # io.read_byte # => 97
  # io.read_byte # => nil
  # ```
  def read_byte : UInt8?
    byte = uninitialized UInt8
    if read(Slice.new(pointerof(byte), 1)) == 1
      byte
    else
      nil
    end
  end

  # Invokes the given block with each byte (`UInt8`) in this `IO`.
  #
  # ```
  # io = IO::Memory.new("a¿?")
  # io.each_byte do |byte|
  #   puts byte
  # end
  # ```
  #
  # Output:
  #
  # ```text
  # 97
  # 227
  # 129
  # 130
  # ```
  def each_byte : Nil
    while byte = read_byte
      yield byte
    end
  end

  # Rewinds this `IO`. By default this method raises, but including types
  # may implement it.
  def rewind
    unimplemented!
  end

  # Seeks to a given *offset* (in bytes) according to the *whence* argument.
  #
  # The `IO` class raises on this method, but some subclasses, notable
  # `IO::FileDescriptor` and `IO::Memory` implement it.
  #
  # Returns `self`.
  #
  # ```
  # File.write("testfile", "abc")
  #
  # file = File.new("testfile")
  # file.gets(3) # => "abc"
  # file.seek(1, IO::Seek::Set)
  # file.gets(2) # => "bc"
  # file.seek(-1, IO::Seek::Current)
  # file.gets(1) # => "c"
  # ```
  def seek(offset, whence : Seek = Seek::Set)
    unimplemented!
  end

  # Returns the current position (in bytes) in this `IO`.
  #
  # The `IO` class raises on this method, but some subclasses, notable
  # `IO::FileDescriptor` and `IO::Memory` implement it.
  #
  # ```
  # File.write("testfile", "hello")
  #
  # file = File.new("testfile")
  # file.pos     # => 0
  # file.gets(2) # => "he"
  # file.pos     # => 2
  # ```
  def pos
    unimplemented!
  end

  # Sets the current position (in bytes) in this `IO`.
  #
  # The `IO` class raises on this method, but some subclasses, notable
  # `IO::FileDescriptor` and `IO::Memory` implement it.
  #
  # ```
  # File.write("testfile", "hello")
  #
  # file = File.new("testfile")
  # file.pos = 3
  # file.gets_to_end # => "lo"
  # ```
  def pos=(value)
    unimplemented!
  end

  # Same as `pos`.
  def tell
    pos
  end
end
