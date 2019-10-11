require "./core/object.cr"
require "./core/*"
require "./sys/*"
require "./io/*"
require "./time/*"

lib LibC
  $_data : Void*
  $_data_end : Void*
  $_bss : Void*
  $_bss_end : Void*
end

lib LibCrystalMain  
  fun __crystal_main(argc : Int32, argv : UInt8**)
end

fun main(argc : LibC::Int, argv : UInt8**) : LibC::Int
  stack_end = 0u64 # scan from here!
  {% if flag?(:i686) %}
    asm("mov %esp, $0" : "=r"(stack_end) :: "volatile")
  {% else %}
    asm("mov %rsp, $0" : "=r"(stack_end) :: "volatile")
  {% end %}
  Gc._init(LibC._data.address,
           LibC._data_end.address,
           LibC._bss.address,
           LibC._bss_end.address,
           stack_end)
  LibCrystalMain.__crystal_main(argc, argv)
  0
end
