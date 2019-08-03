require "./functions/*"

lib LibC
  fun main(argc : Int32, argv : UInt8**) : Int32
end

private def cleanup
  Stdio.flush
end

fun _start(argc : Int32, argv : UInt8**)
  Stdio.init
  LibC.main argc, argv
  cleanup
  _exit
end

fun exit(status : Int32)
  cleanup
  _exit
end