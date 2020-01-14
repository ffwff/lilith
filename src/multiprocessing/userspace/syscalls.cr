require "./argv_builder.cr"
require "./checked_pointers.cr"
require "./syscall_defs.cr"
require "./syscalls/*"
require "./syscalls/handlers/*"

lib Kernel
  fun ksyscall_sc_ret_driver(reg : Syscall::Data::Registers*) : NoReturn
end

module Syscall
  extend self

  @@locked = false
  class_getter locked

  def lock
    # NOTE: we disable process switching because
    # other processes might do another syscall
    # while the current syscall is still being processed
    @@locked = true
    Idt.switch_processes = false
    Idt.enable
  end

  def unlock
    @@locked = false
    Idt.switch_processes = true
    Idt.disable
  end

  def handler(frame : Syscall::Data::Registers*)
    process = Multiprocessing::Scheduler.current_process.not_nil!
    args = Syscall::Arguments.new frame, process
    syscall_no = args.primary_arg

    # syscall handlers for kernel processes
    if process.kernel_process?
      {% for syscall in %w(mmap_drv process_create_drv sleep_drv) %}
        if syscall_no == SC_{{ syscall.upcase.id }}
          args.primary_arg = Syscall::Handlers.{{ syscall.id }}(args).to_u64
          unlock
          return Kernel.ksyscall_sc_ret_driver(frame)
        end
      {% end %}
      abort "unknown kernel syscall!"
    end

    # syscall handlers for user processes
    {% for syscall in %w(open read write fattr spawn close exit
                        seek getcwd chdir sbrk readdir waitpid
                        ioctl mmap time sleep getenv setenv create
                        truncate waitfd remove munmap) %}
      if syscall_no == SC_{{ syscall.upcase.id }}
        args.primary_arg = Syscall::Handlers.{{ syscall.id }}(args).to_u64
        return
      end
    {% end %}

    args.primary_arg = EINVAL
  end
end

fun ksyscall_handler(frame : Syscall::Data::Registers*)
  Syscall.lock
  Syscall.handler frame
  Syscall.unlock
end
