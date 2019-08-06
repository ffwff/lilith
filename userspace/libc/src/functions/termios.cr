NCCS = 2

lib LibC
  struct Termios
    c_iflag : UInt32
    c_oflag : UInt32
    c_cflag : UInt32
    c_lflag : UInt32
    c_cc    : UInt32[NCCS]
  end
end

fun tcgetattr(fd : Int32, termios_p : LibC::Termios*) : Int32
  ioctl fd, SC_IOCTL_TCSAGETS, termios_p.as(Void*)
  0
end

fun tcsetattr(fd : Int32, optional_actions : Int32, termios_p : LibC::Termios*) : Int32
  ioctl fd, optional_actions, termios_p.as(Void*)
  0
end