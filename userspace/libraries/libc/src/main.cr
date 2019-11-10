require "./functions/*"

lib LibC
  fun main(argc : LibC::Int, argv : UInt8**) : LibC::Int
  fun _init
  fun _fini
end

fun __start_common(argc : LibC::Int, argv : UInt8**)
  LibC._init
  Stdio.init
  exit LibC.main(argc, argv)
end

{% if flag?(:i686) %}
  fun _start(argc : LibC::Int, argv : UInt8**)
    __start_common(argc, argv)
  end
{% elsif flag?(:x86_64) %}
  @[Naked]
  fun _start
    asm("add $$8, %rsp
         pop %rdi
         pop %rsi
         call __start_common"
        ::: "volatile", "memory", "rsi", "rdi")
  end
{% end %}

fun exit(status : LibC::Int)
  LibC._fini
  Stdio.flush
  _exit
end
