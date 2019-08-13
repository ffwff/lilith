require "./functions/*"

lib LibC
  fun main(argc : LibC::Int, argv : UInt8**) : LibC::Int
end

private def cleanup
  Stdio.flush
end

fun _start(argc : LibC::Int, argv : UInt8**)
  Stdio.init
  LibC.main argc, argv
  cleanup
  _exit
end

fun exit(status : LibC::Int)
  cleanup
  _exit
end