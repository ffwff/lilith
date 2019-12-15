module PS2
  extend self

  @@mouse_id = 0
  class_getter mouse_id

  STATUS_PORT = 0x64u16
  BUFFER_PORT = 0x60u16

  def init_controller
    PIC.disable 1
    PIC.disable 12

    # flush output buffer
    while (X86.inb(0x64) & 1) == 1
      X86.inb(0x60)
    end

    # enable interrupts
    wait_write STATUS_PORT, 0x20

    # enable auxillary mouse device
    wait_write STATUS_PORT, 0xA8

    # enable PS2 mouse IRQ
    status = wait_read(BUFFER_PORT) | 2
    wait_write STATUS_PORT, 0x60
    wait_write BUFFER_PORT, status

    # use default settings
    mouse_write 0xF6
    ack

    mouse_write 0xF2
    ack
    @@mouse_id = read.to_i32

    # set mouseid to 3
    {% for i in [200, 100, 80] %}
      # set sample rate to 200/100/80
      mouse_write 0xF3
      ack
      mouse_write {{ i }}
      ack
    {% end %}

    mouse_write 0xF2
    ack
    @@mouse_id = read.to_i32

    # enable mouse
    mouse_write 0xF4
    ack

    # enable keyboard
    wait_write STATUS_PORT, 0xAE

    PIC.enable 1
    PIC.enable 12
  end

  def wait_for_input
    # (must be set before attempting to read data from IO port 0x60)
    while true
      return if X86.inb(STATUS_PORT) & 1 != 0
    end
  end

  def wait_for_output
    # (must be clear before attempting to mouse_write data to IO port 0x60 or IO port 0x64)
    while true
      return if X86.inb(STATUS_PORT) & 2 == 0
    end
  end

  def ack
    if (r = read) != 0xFA
      Serial.print "r: ", r, '\n'
      panic "ACK not received"
    end
  end

  def wait_write(port : UInt16, ch : UInt8)
    wait_for_output
    X86.outb port, ch
  end

  def wait_read(port : UInt16)
    wait_for_input
    X86.inb port
  end

  def mouse_write(ch : UInt8)
    wait_for_output
    X86.outb STATUS_PORT, 0xD4
    wait_for_output
    X86.outb BUFFER_PORT, ch
  end

  def read
    wait_for_input
    X86.inb BUFFER_PORT
  end
end
