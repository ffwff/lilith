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

fun _start(argc : Int32, argv : UInt8**)
  LibC.main argc, argv
  _exit
end
