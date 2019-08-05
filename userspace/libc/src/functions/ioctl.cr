lib LibC

  struct WinSize
    ws_row : UInt16
    ws_col : UInt16
    ws_xpixel : UInt16
    ws_ypixel : UInt16
  end

end

TIOCGWINSZ = 0

fun ioctl(fd : Int32, request : Int32, arg : Void*) : Int32
  if request == TIOCGWINSZ
    arg = arg.as(LibC::WinSize*)
    # TODO
    arg.value.ws_row = 25
    arg.value.ws_col = 80
    arg.value.ws_xpixel = 16
    arg.value.ws_ypixel = 8
    0
  else
    -1
  end
end