require "./functions/*"

lib LibC
  fun main(argc : Int32, argv : UInt8**) : Int32
end

fun _start(argc : Int32, argv : UInt8**)
  LibC.main argc, argv
  _exit
end
