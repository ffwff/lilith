module X86
  extend self

  def outb(port : UInt16, val : UInt8)
    asm("outb $1, $0" :: "{dx}"(port), "{al}"(val) :: "volatile")
  end

  def outw(port : UInt16, val : UInt16)
    asm("outw $1, $0" :: "{dx}"(port), "{ax}"(val) :: "volatile")
  end

  def outl(port : UInt16, val : UInt32)
    asm("outl $1, $0" :: "{dx}"(port), "{eax}"(val) :: "volatile")
  end

  def inb(port : UInt16) : UInt8
    result = 0_u8
    asm("inb $1, $0" : "={al}"(result) : "{dx}"(port) :: "volatile")
    result
  end

  def inw(port : UInt16) : UInt16
    result = 0_u16
    asm("inw $1, $0" : "={ax}"(result) : "{dx}"(port) :: "volatile")
    result
  end

  def inl(port : UInt16) : UInt32
    result = 0_u32
    asm("inl $1, $0" : "={eax}"(result) : "{dx}"(port) :: "volatile")
    result
  end
end
