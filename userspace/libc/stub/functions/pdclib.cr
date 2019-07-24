fun _PDCLIB_open(filename : LibC::String, mode : UInt32) : Int32
  -1
end

fun _PDCLIB_close(fd : Int32) : Int32
  close fd
end

fun _PDCLIB_Exit(status : Int32)
  _exit
end
