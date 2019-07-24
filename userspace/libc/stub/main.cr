require "./functions/pdclib.cr"
require "./functions/malloc.cr"
require "./functions/string.cr"

# architecture specific
require "./functions/syscalls.cr"
require "./functions/threads.cr"
require "./functions/setjmp.cr"
require "./functions/dirent.cr"

lib LibC
  fun main(argc : Int32, argv : UInt8**) : Int32
end

fun _start
  open "/kbd\0".to_unsafe, 0 # stdin
  open "/vga\0".to_unsafe, 0 # stdout
  LibC.main 0, Pointer(UInt8*).null
  _exit
end
