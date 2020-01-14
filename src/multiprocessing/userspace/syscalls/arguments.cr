module Syscall
  struct Arguments
    getter frame, process

    def initialize(@frame : Syscall::Data::Registers*,
                   @process : Multiprocessing::Process)
    end

    def primary_arg
      @frame.value.rax
    end

    def primary_arg=(code)
      @frame.value.rax = code
    end

    def [](idx)
      case idx
      when 0
        @frame.value.rbx
      when 1
        @frame.value.rdx
      when 2
        @frame.value.rdi
      when 3
        @frame.value.rsi
      when 4
        @frame.value.r8
      else
        abort "unknown syscall argument index"
      end
    end
  end
end
