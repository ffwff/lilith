module Syscalls

  struct Arguments
    getter frame, process

    def initialize(@frame : Syscall::Data::Registers*,
                   @process : Multiprocessing::Process)
    end

    def sysret(code)
      @frame.value.rax = code
    end

    def [](num)
      {%
        arg_registers = [
          "rbx", "rdx", "rdi", "rsi", "r8",
        ]
      %}
      fv.{{ arg_registers[num].id }}
    end
  end

end
