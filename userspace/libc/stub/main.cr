require "./functions/threads.cr"
require "./functions/syscalls.cr"
require "./functions/pdclib.cr"
require "./functions/malloc.cr"
require "./functions/string.cr"
require "./functions/dirent.cr"

lib LibC
  fun main(argc : Int32, argv : UInt8**) : Int32
end

fun _start
  open cstrptr("/kbd"), 0 # stdin
  open cstrptr("/vga"), 0 # stdout
  LibC.main 0, Pointer(UInt8*).null
  _exit
end
