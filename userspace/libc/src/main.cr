require "./functions/*"

lib LibC
  fun main(argc : LibC::Int, argv : UInt8**) : LibC::Int
  fun _init
  fun _fini
end

fun _start(argc : LibC::Int, argv : UInt8**)
  LibC._init
  Stdio.init
  LibC.main argc, argv
  exit 0
end

fun exit(status : LibC::Int)
  LibC._fini
  Stdio.flush
  _exit
end