NCCS = 2

lib LibC
  struct Termios
    c_iflag : LibC::UInt
    c_oflag : LibC::UInt
    c_cflag : LibC::UInt
    c_lflag : LibC::UInt
    c_cc    : UInt8[NCCS]
  end
end

fun tcgetattr(fd : LibC::Int, termios_p : LibC::Termios*) : LibC::Int
  ioctl fd, SC_IOCTL_TCSAGETS, termios_p.as(Void*)
  0
end

fun tcsetattr(fd : LibC::Int,
              optional_actions : LibC::Int,
              termios_p : LibC::Termios*) : LibC::Int
  ioctl fd, optional_actions, termios_p.as(Void*)
  0
end