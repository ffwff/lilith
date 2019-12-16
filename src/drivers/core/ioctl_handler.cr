module TermiosData
  VTIME = 0
  VMIN  = 1
  NCSS  = 2

  @[Flags]
  enum IFlag : UInt32
    BRKINT = 1 << 0
    ICRNL  = 1 << 1
    INPCK  = 1 << 2
    ISTRIP = 1 << 3
    IXON   = 1 << 4
    OPOST  = 1 << 5
  end

  @[Flags]
  enum OFlag : UInt32
    OPOST = 1 << 0
  end

  @[Flags]
  enum CFlag : UInt32
    CS8 = 1 << 0
  end

  @[Flags]
  enum LFlag : UInt32
    ECHO   = 1 << 0
    ICANON = 1 << 1
    IEXTEN = 1 << 2
    ISIG   = 1 << 3
  end
end

lib IoctlData
  @[Packed]
  struct Winsize
    ws_row : UInt16
    ws_col : UInt16
    ws_xpixel : UInt16
    ws_ypixel : UInt16
  end

  @[Packed]
  struct Termios
    c_iflag : TermiosData::IFlag
    c_oflag : TermiosData::OFlag
    c_cflag : TermiosData::CFlag
    c_lflag : TermiosData::LFlag
    c_cc : UInt8[TermiosData::NCSS]
  end
end

module IoctlHandler
  extend self

  def winsize(data, width, height, x_pix, y_pix)
    data = data.as(IoctlData::Winsize*)
    data.value.ws_row = height
    data.value.ws_col = width
    data.value.ws_xpixel = x_pix
    data.value.ws_ypixel = y_pix
    0
  end

  def tcsa_gets(data, &block)
    data = data.as(IoctlData::Termios*)
    termios = IoctlData::Termios.new
    termios.c_iflag = TermiosData::IFlag::None
    termios.c_oflag = TermiosData::OFlag::None
    termios.c_cflag = TermiosData::CFlag::None
    termios.c_lflag = TermiosData::LFlag::None
    data.value = yield termios
    0
  end
end
