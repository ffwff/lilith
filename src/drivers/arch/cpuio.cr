module X86
  extend self

  def flush_memory
    asm("" ::: "memory")
  end

  # Sends a hardware output to `port` with byte value `val`
  def outb(port : UInt16, val : UInt8)
    asm("outb $1, $0" :: "{dx}"(port), "{al}"(val) : "volatile")
  end

  # Sends a hardware output to `port` with word value `val`
  def outw(port : UInt16, val : UInt16)
    asm("outw $1, $0" :: "{dx}"(port), "{ax}"(val) : "volatile")
  end

  # Sends a hardware output to `port` with long value `val`
  def outl(port : UInt16, val : UInt32)
    asm("outl $1, $0" :: "{dx}"(port), "{eax}"(val) : "volatile")
  end

  # Reads a byte value from `port`
  def inb(port : UInt16) : UInt8
    result = 0_u8
    asm("inb $1, $0" : "={al}"(result) : "{dx}"(port) : "volatile")
    result
  end

  # Reads a word value from `port`
  def inw(port : UInt16) : UInt16
    result = 0_u16
    asm("inw $1, $0" : "={ax}"(result) : "{dx}"(port) : "volatile")
    result
  end

  # Reads a long value from `port`
  def inl(port : UInt16) : UInt32
    result = 0_u32
    asm("inl $1, $0" : "={eax}"(result) : "{dx}"(port) : "volatile")
    result
  end

  # Waits for ~3 microseconds
  def io_delay
    32.times do
      X86.inb 0x80
    end
  end
end
