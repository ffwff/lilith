require "./core/object.cr"
require "./sys/types.cr"
require "./core/*"
require "./sys/*"
require "./io/io.cr"
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

fun __crystal_once_init : Void*
  Pointer(Void).new 0
end

fun __crystal_once(state : Void*, flag : Bool*, initializer : Void*)
  unless flag.value
    Proc(Nil).new(initializer, Pointer(Void).new 0).call
    flag.value = true
  end
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
  STDOUT.flush
  0
end
