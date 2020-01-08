require "./syscall_defs.cr"
require "./checked_pointers.cr"
require "./argv_builder.cr"

lib Kernel
  fun ksyscall_sc_ret_driver(reg : Syscall::Data::Registers*) : NoReturn
end

module Syscall
  extend self

  lib Data
    struct Registers
      ds : UInt64
      rbp, rdi, rsi,
r15, r14, r13, r12, r11, r10, r9, r8,
rdx, rcx, rbx, rax : UInt64
      rsp : UInt64
    end

    alias Ino32 = Int32

    @[Packed]
    struct DirentArgument32
      # Inode number
      d_ino : Ino32
      # Length of this record
      d_reclen : UInt16
      # Type of file; not supported by all filesystem types
      d_type : UInt8
      # Null-terminated filename
      d_name : UInt8[256]
    end

    @[Packed]
    struct SpawnStartupInfo32
      stdin : Int32
      stdout : Int32
      stderr : Int32
    end

    @[Flags]
    enum MmapProt : Int32
      Read    = 1 << 0
      Write   = 1 << 1
      Execute = 1 << 2
    end
  end

  @@locked = false
  class_getter locked

  def lock
    # NOTE: we disable process switching because
    # other processes might do another syscall
    # while the current syscall is still being processed
    @@locked = true
    GC.needs_scan_kernel_stack = true
    Idt.switch_processes = false
    Idt.enable
  end

  def unlock
    @@locked = false
    GC.needs_scan_kernel_stack = false
    Idt.switch_processes = true
    Idt.disable
  end

  def handler(frame : Syscall::Data::Registers*)
    process = Multiprocessing::Scheduler.current_process.not_nil!
    args = Syscall::Arguments.new frame, process

    # syscall handlers for kernel processes
    if process.kernel_process?
      {% for syscall %w(mmap_drv process_create_drv) %}
        if frame.value.rax == SC_{{ syscall.upper }}
          if retval = Syscall::Handlers.{{ syscall }} args
            frame.value.rax = retval
          end
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
      if frame.value.rax == SC_{{ syscall.upper }}
        if retval = Syscall::Handlers.{{ syscall }} args
          frame.value.rax = retval
        end
        return
      end
    {% end %}
    frame.value.rax = EINVAL
  end
end

fun ksyscall_handler(frame : Syscall::Data::Registers*)
  Syscall.lock
  Syscall.handler frame
  Syscall.unlock
end
