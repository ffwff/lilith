class Mouse
  @mousefs : MouseFS? = nil
  property mousefs

  def initialize
    Idt.register_irq 12, ->callback

    # enable auxillary mouse device
    wait true
    X86.outb(0x64, 0xA8)

    # enable interrupts
    wait true
    X86.outb(0x64, 0x20)
    wait false
    _status = X86.inb(0x60) | 2
    wait true
    X86.outb(0x64, 0x60)
    wait true
    X86.outb(0x60, _status)

    # use default settings
    write 0xF6
    read # ACK

    # enable mouse
    write 0xF4
    read # ACK

    # reset ps2 keyboard scancode
    wait true
    X86.outb(0x60, 0xF0)
    wait true
    X86.outb(0x60, 0x02)
    wait true
    read # ACK
  end

  private def wait(signal?)
    timeout = 100000
    if !signal? # data
      timeout.times do |i|
        return if X86.inb(0x64) & 1 == 1
      end
    else # signal
      timeout.times do |i|
        return if X86.inb(0x64) & 2 == 1
      end
    end
  end

  private def write(ch : UInt8)
    wait true
    X86.outb(0x64, 0xD4)
    wait true
    X86.outb(0x60, ch)
  end

  private def read
    wait false
    X86.inb 0x60
  end

  @[Flags]
  enum AttributeByte
    LeftBtn = 1 << 0
    RightBtn = 1 << 1
    MiddleBtn = 1 << 2
    AlwaysOne = 1 << 3
    XSign = 1 << 4
    YSign = 1 << 5
    XOverflow = 1 << 6
    YOverflow = 1 << 7
  end

  @cycle = 0
  @attr_byte = AttributeByte::None
  @x = 0
  @y = 0

  def flush
    tuple = Tuple.new(@x, @y, @attr_byte)
    @attr_byte = AttributeByte::None
    @x = 0
    @y = 0
    tuple
  end

  def callback
    packet_finished = false

    # build the packet
    case @cycle
    when 0
      @attr_byte = AttributeByte.new(X86.inb(0x60).to_i32)
      unless @attr_byte.includes?(AttributeByte::AlwaysOne)
        @cycle = 0
        return
      end
      @cycle += 1
    when 1
      @x = X86.inb(0x60)
      @cycle += 1
    when 2
      @y = X86.inb(0x60)
      @cycle = 0
      packet_finished = true
    end

    # process it
    if packet_finished
      # complete the packet
      if @attr_byte.includes?(AttributeByte::XSign)
        @x = (@x.to_u32 | 0xFFFFFF00).to_i32
      end
      if @attr_byte.includes?(AttributeByte::YSign)
        @y = (@y.to_u32 | 0xFFFFFF00).to_i32
      end
      if @attr_byte.includes?(AttributeByte::XOverflow) ||
         @attr_byte.includes?(AttributeByte::YOverflow)
        @x = 0
        @y = 0
      end
    end
  end

end