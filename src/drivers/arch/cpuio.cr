module X86
  extend self

  @[AlwaysInline]
  def outb(port : UInt16, val : UInt8)
    asm("outb $1, $0" :: "{dx}"(port), "{al}"(val) :: "volatile")
  end

  @[AlwaysInline]
  def outw(port : UInt16, val : UInt16)
    asm("outw $1, $0" :: "{dx}"(port), "{ax}"(val) :: "volatile")
  end

  @[AlwaysInline]
  def outl(port : UInt16, val : UInt32)
    asm("outl $1, $0" :: "{dx}"(port), "{eax}"(val) :: "volatile")
  end

  @[AlwaysInline]
  def inb(port : UInt16) : UInt8
    result = 0_u8
    asm("inb $1, $0" : "={al}"(result) : "{dx}"(port) :: "volatile")
    result
  end

  @[AlwaysInline]
  def inw(port : UInt16) : UInt16
    result = 0_u16
    asm("inw $1, $0" : "={ax}"(result) : "{dx}"(port) :: "volatile")
    result
  end

  @[AlwaysInline]
  def inl(port : UInt16) : UInt32
    result = 0_u32
    asm("inl $1, $0" : "={eax}"(result) : "{dx}"(port) :: "volatile")
    result
  end
end
