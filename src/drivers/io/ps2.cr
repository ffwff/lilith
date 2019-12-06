module PS2
  extend self

  @@mouse_id = 0
  class_getter mouse_id

  def init_controller
    wait true
    write 0xFF
    while read != 0xAA
    end

    # flush buffer
    while (X86.inb(0x64) & 1) != 0
      X86.inb 0x60
    end

    # enable auxillary mouse device
    wait true
    X86.outb(0x64, 0xA8)
    read

    # enable irq
    wait true
    X86.outb(0x64, 0x20)
    wait false
    status = X86.inb(0x60) | 3
    wait true
    X86.outb(0x64, 0x60)
    wait true
    X86.outb(0x60, status)

    write 0xF2
    read
    @@mouse_id = read.to_i32

    # set mouseid to 3
    {% for i in [200, 100, 80] %}
      # set sample rate to 200/100/80
      write 0xF3
      read # ACK
      write {{ i }}
      read # ACK
    {% end %}

    write 0xF2
    read
    @@mouse_id = read.to_i32

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

  def wait(signal?)
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

  def write(ch : UInt8)
    wait true
    X86.outb(0x64, 0xD4)
    wait true
    X86.outb(0x60, ch)
  end

  def read
    wait false
    X86.inb 0x60
  end

end
