require "./sys/*"
require "./core/*"
require "./io/*"

lib LibCrystalMain  
  fun __crystal_main(argc : Int32, argv : UInt8**)
end

fun main(argc : LibC::Int, argv : UInt8**) : LibC::Int
  LibCrystalMain.__crystal_main(argc, argv)
  0
end
