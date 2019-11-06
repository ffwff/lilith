require "./functions/*"

lib LibC
  fun main(argc : LibC::Int, argv : UInt8**) : LibC::Int
  fun _init
  fun _fini
end

private def start_common(argc, argv)
  LibC._init
  Stdio.init
  exit LibC.main(argc, argv)
end

{% if flag?(:i686) %}
  fun _start(argc : LibC::Int, argv : UInt8**)
    start_common(argc, argv)
  end
{% elsif flag?(:x86_64) %}
  @[Naked]
  fun _start
    argc : LibC::Int = 0
    argv = Pointer(UInt8*).null
    asm("add $$8, %rsp
         pop %rcx
         pop %rdx"
        : "={rcx}"(argc), "={rdx}"(argv)
        :: "volatile", "memory")
    start_common(argc, argv)
  end
{% end %}

fun exit(status : LibC::Int)
  LibC._fini
  Stdio.flush
  _exit
end
