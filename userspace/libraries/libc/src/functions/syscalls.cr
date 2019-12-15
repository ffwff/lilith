require "../syscall_defs.cr"

# sysenter implementations
{% if flag?(:i686) %}
@[AlwaysInline]
private def lilith_syscall(eax : UInt32, ebx : UInt32,
                             edx = 0u32, edi = 0u32, esi = 0u32) : Int32
  shadow = uninitialized UInt32[2]
  shadowptr = shadow.to_unsafe
  asm("mov %esp, 4($0)" :: "r"(shadowptr) : "volatile", "memory", "{esp}")
  ret = 0
  l0 = l1 = 0
  asm("movd $$1f, (%esp)
       mov %esp, %ecx
       sysenter
      1: mov 4(%esp), %esp"
      : "={eax}"(ret), "={edi}"(l0), "={esi}"(l1)
      : "{esp}"(shadowptr), "{eax}"(eax), "{ebx}"(ebx), "{edx}"(edx), "{edi}"(edi), "{esi}"(esi)
      : "cc", "memory", "volatile", "ecx", "esp")
  ret
end

@[AlwaysInline]
private def lilith_syscall64(eax : UInt32, ebx : UInt32,
                               edx = 0u32, edi = 0u32, esi = 0u32) : UInt64
  shadow = uninitialized UInt32[2]
  shadowptr = shadow.to_unsafe
  asm("mov %esp, 4($0)" :: "r"(shadowptr) : "volatile", "memory", "{esp}")
  ret_lo, ret_hi = 0u64, 0u64
  l0 = l1 = 0
  asm("movd $$1f, (%esp)
       mov %esp, %ecx
       sysenter
      1: mov 4(%esp), %esp"
      : "={eax}"(ret_lo), "={ebx}"(ret_hi), "={edi}"(l0), "={esi}"(l1)
      : "{esp}"(shadowptr), "{eax}"(eax), "{ebx}"(ebx), "{edx}"(edx), "{edi}"(edi), "{esi}"(esi)
      : "cc", "memory", "volatile", "ecx", "esp")
  ret
  (ret_hi << 32) | ret_lo
end
{% elsif flag?(:x86_64) %}
@[AlwaysInline]
private def lilith_syscall(rax : UInt32, rbx : UInt64,
                             rdx = 0u64, rdi = 0u64, rsi = 0u64) : Int32
  shadow = uninitialized UInt64[2]
  shadowptr = shadow.to_unsafe
  asm("mov %rsp, 8($0)" :: "r"(shadowptr) : "volatile", "memory", "{rsp}")
  ret = 0
  l0 = l1 = 0
  asm("movq $$1f, (%rsp)
       mov %rsp, %rcx
       syscall
      1: mov 8(%rsp), %rsp"
      : "={rax}"(ret), "={rdi}"(l0), "={rsi}"(l1)
      : "{rsp}"(shadowptr), "{rax}"(rax), "{rbx}"(rbx), "{rdx}"(rdx), "{rdi}"(rdi), "{rsi}"(rsi)
      : "cc", "memory", "volatile", "rcx", "rsp", "r11", "r12")
  ret
end

@[AlwaysInline]
private def lilith_syscall64(rax : UInt32, rbx : UInt64,
                               rdx = 0u64, rdi = 0u64, rsi = 0u64) : UInt64
  shadow = uninitialized UInt64[2]
  shadowptr = shadow.to_unsafe
  asm("mov %rsp, 8($0)" :: "r"(shadowptr) : "volatile", "memory", "{rsp}")
  ret = 0u64
  l0 = l1 = 0
  asm("movq $$1f, (%rsp)
       mov %rsp, %rcx
       syscall
      1: mov 8(%rsp), %rsp"
      : "={rax}"(ret), "={rdi}"(l0), "={rsi}"(l1)
      : "{rsp}"(shadowptr), "{rax}"(rax), "{rbx}"(rbx), "{rdx}"(rdx), "{rdi}"(rdi), "{rsi}"(rsi)
      : "cc", "memory", "volatile", "rcx", "rsp", "r11", "r12")
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
    ext = uninitialized UInt32[2]
    ext[0] = addr.address.to_u32
    ext[1] = size
    Pointer(Void).new(lilith_syscall(SC_MMAP, fd.to_usize, prot.to_usize, flags.to_usize, ext.to_unsafe.address).to_u32)
  {% else %}
    ext = uninitialized UInt64[2]
    ext[0] = addr.address
    ext[1] = size
    Pointer(Void).new(lilith_syscall64(SC_MMAP, fd.to_usize, prot.to_usize, flags.to_usize, ext.to_unsafe.address))
  {% end %}
end

fun munmap(addr : Void*)
  lilith_syscall(SC_MUNMAP, addr.address.to_usize)
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
    lilith_syscall(SC_GETCWD, retval, len.to_usize).to_int
    retval
  else
    lilith_syscall(SC_GETCWD, str, len).to_int
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

# time
fun time(tloc : Void*) : LibC::UInt
  # TODO
  0u32
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
