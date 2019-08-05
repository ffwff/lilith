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
  0
end

fun tcsetattr(fd : Int32, optional_actions : Int32, termios_p : LibC::Termios*) : Int32
  0
end