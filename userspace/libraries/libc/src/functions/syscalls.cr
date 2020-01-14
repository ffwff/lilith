require "../syscall_defs.cr"

{% if flag?(:x86_64) %}
  @[NoInline]
  private def lilith_syscall(rax : UInt32, rbx : UInt64,
                             rdx = 0u64, rdi = 0u64, rsi = 0u64,
                             r8 = 0u64) : Int32
    ret = 0
    l = 0
    asm("push $$1f
       mov %rsp, %rcx
       syscall
       1: add $$8, %rsp"
            : "={rax}"(ret), "={rdi}"(l), "={rsi}"(l), "={r11}"(l), "={r12}"(l)
            : "{rax}"(rax), "{rbx}"(rbx), "{rdx}"(rdx), "{rdi}"(rdi), "{rsi}"(rsi), "{r8}"(r8)
            : "cc", "memory", "volatile", "rcx", "r11", "r12")
    ret
  end

  @[NoInline]
  private def lilith_syscall64(rax : UInt32, rbx : UInt64,
                               rdx = 0u64, rdi = 0u64, rsi = 0u64,
                               r8 = 0u64) : UInt64
    ret = 0u64
    l = 0
    asm("push $$1f
       mov %rsp, %rcx
       syscall
       1: add $$8, %rsp"
            : "={rax}"(ret), "={rdi}"(l), "={rsi}"(l), "={r11}"(l), "={r12}"(l)
            : "{rax}"(rax), "{rbx}"(rbx), "{rdx}"(rdx), "{rdi}"(rdi), "{rsi}"(rsi), "{r8}"(r8)
            : "cc", "memory", "volatile", "rcx", "r11", "r12")
    ret
  end
{% end %}

@[AlwaysInline]
private def lilith_syscall(eax : UInt32, fd : Int32) : Int32
  lilith_syscall(eax, fd.to_usize)
end

@[AlwaysInline]
private def lilith_syscall(eax : UInt32,
                           str : UInt8*,
                           len : LibC::SizeT,
                           flag : Int32 = 0)
  lilith_syscall(eax, str.address.to_usize, len, flag.to_usize)
end

@[AlwaysInline]
private def lilith_syscall(eax : UInt32,
                           fd : Int32,
                           str : UInt8*,
                           len : LibC::SizeT)
  lilith_syscall(eax, fd.to_usize, str.address.to_usize, len)
end

@[AlwaysInline]
private def lilith_syscall(eax : UInt32,
                           fd : Int32,
                           generic : Void*)
  lilith_syscall(eax, fd.to_usize, generic.address.to_usize)
end

@[AlwaysInline]
private def lilith_syscall(eax : UInt32,
                           str : UInt8*,
                           len : LibC::SizeT,
                           s_info : Void*,
                           argv : UInt8**)
  lilith_syscall(eax, str.address.to_usize, len, s_info.address.to_usize, argv.address.to_usize)
end

# IO
fun _open(device : UInt8*, flags : LibC::Int) : LibC::Int
  lilith_syscall(SC_OPEN, device, strlen(device), flags)
end

fun create(device : UInt8*, flags : LibC::Int) : LibC::Int
  lilith_syscall(SC_CREATE, device, strlen(device), flags)
end

fun fattr(fd : LibC::Int) : LibC::Int
  lilith_syscall(SC_FATTR, fd).to_int
end

fun close(fd : LibC::Int) : LibC::Int
  lilith_syscall(SC_CLOSE, fd).to_int
end

fun read(fd : LibC::Int, str : UInt8*, len : LibC::SizeT) : LibC::Int
  lilith_syscall(SC_READ, fd, str, len).to_int
end

fun write(fd : LibC::Int, str : UInt8*, len : LibC::SizeT) : LibC::Int
  lilith_syscall(SC_WRITE, fd, str, len).to_int
end

fun ftruncate(fd : LibC::Int, length : LibC::SizeT) : LibC::Int
  lilith_syscall(SC_TRUNCATE, fd.to_usize, length.to_usize).to_int
end

fun lseek(fd : LibC::Int, offset : Int32, whence : LibC::Int) : Int32
  lilith_syscall(SC_SEEK, fd.to_usize, offset.to_usize, whence.to_usize).to_int
end

fun lseek64(fd : LibC::Int, offset : Int64, whence : LibC::Int) : Int64
  (-1).to_i64
end

fun _ioctl(fd : LibC::Int, request : LibC::Int, data : LibC::ULong) : LibC::Int
  lilith_syscall(SC_IOCTL, fd.to_usize, request.to_usize, data.to_usize).to_int
end

fun waitfd(fds : LibC::Int*, nfd : LibC::SizeT, timeout : LibC::UsecondsT) : LibC::Int
  lilith_syscall(SC_WAITFD, fds.address.to_usize, nfd.to_usize, timeout.to_usize).to_int
end

fun remove(str : UInt8*) : LibC::Int
  lilith_syscall(SC_REMOVE, str, strlen(str)).to_int
end

fun mmap(addr : Void*, size : LibC::SizeT, prot : LibC::Int,
         flags : LibC::Int, fd : LibC::Int, offset : LibC::OffT) : Void*
  {% if flag?(:bits32) %}
    Pointer(Void).new(lilith_syscall(SC_MMAP, fd.to_usize, prot.to_usize, flags.to_usize, addr.address.to_u32, size.to_u32).to_u32)
  {% else %}
    Pointer(Void).new(lilith_syscall64(SC_MMAP, fd.to_usize, prot.to_usize, flags.to_usize, addr.address.to_u64, size.to_u64))
  {% end %}
end

fun munmap(addr : Void*, length : LibC::SizeT)
  lilith_syscall(SC_MUNMAP, addr.address.to_usize, length.to_usize)
end

fun lilith_readdir(fd : LibC::Int, direntp : Void*) : LibC::Int
  lilith_syscall(SC_READDIR, fd, direntp).to_int
end

# process
fun _exit : Nil
  lilith_syscall(SC_EXIT, 0)
end

fun raise(sig : LibC::Int) : LibC::Int
  -1
end

fun abort : NoReturn
  Pointer(LibC::UInt).null.value = 0
  while true
  end
end

fun spawnv(file : UInt8*, argv : UInt8**) : LibC::Pid
  lilith_syscall(SC_SPAWN, file, strlen(file), Pointer(Void).null, argv)
end

fun spawnxv(s_info : Void*, file : UInt8*, argv : UInt8**) : LibC::Pid
  lilith_syscall(SC_SPAWN, file, strlen(file), s_info, argv)
end

fun waitpid(pid : LibC::Pid, status : LibC::Int*, options : LibC::Int) : LibC::Pid
  lilith_syscall(SC_WAITPID, pid.to_usize).to_int
end

fun usleep(timeout : LibC::UsecondsT) : LibC::Int
  lilith_syscall(SC_SLEEP, timeout >> 32, timeout & 0xFFFF_FFFF).to_int
end

fun _sys_time : LibC::TimeT
  lilith_syscall64(SC_TIME, 0.to_usize)
end

# working directory
fun getcwd(str : UInt8*, len : LibC::SizeT) : UInt8*
  if str.null?
    len = lilith_syscall(SC_GETCWD, 0.to_usize, 0.to_usize).to_int + 1
    retval = Pointer(UInt8).malloc len.to_usize
    lilith_syscall(SC_GETCWD, retval, len.to_usize)
    retval
  else
    lilith_syscall(SC_GETCWD, str, len)
    str
  end
end

fun chdir(str : UInt8*) : LibC::Int
  lilith_syscall(SC_CHDIR, str, strlen(str)).to_int
end

# malloc
fun sbrk(increment : LibC::SizeT) : Void*
  Pointer(Void).new(lilith_syscall(SC_SBRK, increment).to_u64)
end

# stat
fun stat(path : UInt8*, statbuf : Void*) : LibC::Int
  # TODO
  -1
end

fun access(path : UInt8*, mode : LibC::Int) : LibC::Int
  # TODO
  -1
end

fun unlink(path : UInt8*) : LibC::Int
  # TODO
  -1
end

fun rename(oldpath : UInt8*, newpath : UInt8*) : LibC::Int
  # TODO
  -1
end

fun system(command : UInt8*) : LibC::Int
  # TODO
  0
end
