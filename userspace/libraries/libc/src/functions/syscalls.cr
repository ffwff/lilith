require "../syscall_defs.cr"

# sysenter implementations
{% if flag?(:i686) %}
@[AlwaysInline]
private def __lilith_syscall(eax : UInt32, ebx : UInt32,
                             edx = 0u32, edi = 0u32, esi = 0u32) : Int32
  ret = 0
  l0 = l1 = 0
  asm("push $$1f
       mov %esp, %ecx
       sysenter
       1: add $$4, %esp"
          : "={eax}"(ret), "={edi}"(l0), "={esi}"(l1)
          : "{eax}"(eax), "{ebx}"(ebx), "{edx}"(edx), "{edi}"(edi), "{esi}"(esi)
          : "cc", "ecx", "memory", "volatile")
  ret
end

@[AlwaysInline]
private def __lilith_syscall64(eax : UInt32, ebx : UInt32,
                               edx = 0u32, edi = 0u32, esi = 0u32) : UInt64
  ret_lo, ret_hi = 0u64, 0u64
  l0 = l1 = 0
  asm("push $$1f
       mov %esp, %ecx
       sysenter
       1: add $$4, %esp"
          : "={eax}"(ret_lo), "={ebx}"(ret_hi), "={edi}"(l0), "={esi}"(l1)
          : "{eax}"(eax), "{ebx}"(ebx), "{edx}"(edx), "{edi}"(edi), "{esi}"(esi)
          : "cc", "ecx", "memory", "volatile")
  (ret_hi << 32) | ret_lo
end
{% elsif flag?(:x86_64) %}
@[AlwaysInline]
private def __lilith_syscall(rax : UInt32, rbx : UInt64,
                             rdx = 0u64, rdi = 0u64, rsi = 0u64) : Int32
  ret = 0
  l0 = l1 = 0
  asm("push $$1f
       mov %rsp, %rcx
       sysenter
       1: add $$8, %rsp"
          : "={rax}"(ret), "={rdi}"(l0), "={rsi}"(l1)
          : "{rax}"(rax), "{rbx}"(rbx), "{rdx}"(rdx), "{rdi}"(rdi), "{rsi}"(rsi)
          : "cc", "ecx", "memory", "volatile")
  ret
end

@[AlwaysInline]
private def __lilith_syscall64(rax : UInt32, rbx : UInt64,
                               rdx = 0u64, rdi = 0u64, rsi = 0u64) : UInt64
  ret = 0u64
  l0 = l1 = 0
  asm("push $$1f
       mov %rsp, %rcx
       sysenter
       1: add $$8, %rsp"
          : "={rax}"(ret), "={rdi}"(l0), "={rsi}"(l1)
          : "{rax}"(rax), "{rbx}"(rbx), "{rdx}"(rdx), "{rdi}"(rdi), "{rsi}"(rsi)
          : "cc", "ecx", "memory", "volatile")
  ret
end
{% end %}

@[AlwaysInline]
private def __lilith_syscall(eax : UInt32, fd : Int32) : Int32
  __lilith_syscall(eax, fd.to_usize)
end

@[AlwaysInline]
private def __lilith_syscall(eax : UInt32,
                             str : LibC::String,
                             len : LibC::SizeT,
                             flag : Int32 = 0)
  __lilith_syscall(eax, str.address.to_usize, len, flag.to_usize)
end

@[AlwaysInline]
private def __lilith_syscall(eax : UInt32,
                             fd : Int32,
                             str : LibC::String,
                             len : LibC::SizeT)
  __lilith_syscall(eax, fd.to_usize, str.address.to_usize, len)
end

@[AlwaysInline]
private def __lilith_syscall(eax : UInt32,
                             fd : Int32,
                             generic : Void*)
  __lilith_syscall(eax, fd.to_usize, generic.address.to_usize)
end

@[AlwaysInline]
private def __lilith_syscall(eax : UInt32,
                             str : LibC::String,
                             len : LibC::SizeT,
                             s_info : Void*,
                             argv : UInt8**)
  __lilith_syscall(eax, str.address.to_usize, len, s_info.address.to_usize, argv.address.to_usize)
end

# IO
fun _open(device : LibC::String, flags : LibC::Int) : LibC::Int
  __lilith_syscall(SC_OPEN, device, strlen(device), flags)
end

fun create(device : LibC::String, flags : LibC::Int) : LibC::Int
  __lilith_syscall(SC_CREATE, device, strlen(device), flags)
end

fun close(fd : LibC::Int) : LibC::Int
  __lilith_syscall(SC_CLOSE, fd).to_int
end

fun read(fd : LibC::Int, str : LibC::String, len : LibC::SizeT) : LibC::Int
  __lilith_syscall(SC_READ, fd, str, len).to_int
end

fun write(fd : LibC::Int, str : LibC::String, len : LibC::SizeT) : LibC::Int
  __lilith_syscall(SC_WRITE, fd, str, len).to_int
end

fun ftruncate(fd : LibC::Int, length : LibC::SizeT) : LibC::Int
  __lilith_syscall(SC_TRUNCATE, fd.to_usize, length.to_usize).to_int
end

fun lseek(fd : LibC::Int, offset : Int32, whence : LibC::Int) : Int32
  __lilith_syscall(SC_SEEK, fd.to_usize, offset.to_usize, whence.to_usize).to_int
end

fun lseek64(fd : LibC::Int, offset : Int64, whence : LibC::Int) : Int64
  (-1).to_i64
end

fun _ioctl(fd : LibC::Int, request : LibC::Int, data : LibC::ULong) : LibC::Int
  __lilith_syscall(SC_IOCTL, fd.to_usize, request.to_usize, data.to_usize).to_int
end

fun waitfd(fds : LibC::Int*, nfd : LibC::SizeT, timeout : LibC::UInt) : LibC::Int
  __lilith_syscall(SC_WAITFD, fds.address.to_usize, nfd.to_usize, timeout.to_usize).to_int
end

fun remove(str : LibC::String) : LibC::Int
  __lilith_syscall(SC_REMOVE, str, strlen(str)).to_int
end

fun mmap(fd : LibC::Int, size : LibC::SizeT) : Void*
  Pointer(Void).new(__lilith_syscall(SC_MMAP, fd.to_usize, size.to_usize).to_u64)
end

fun munmap(addr : Void*)
  __lilith_syscall(SC_MUNMAP, addr.address.to_usize)
end

fun lilith_readdir(fd : LibC::Int, direntp : Void*) : LibC::Int
  __lilith_syscall(SC_READDIR, fd, direntp).to_int
end

# process
fun _exit : Nil
  __lilith_syscall(SC_EXIT, 0)
end

fun raise(sig : LibC::Int) : LibC::Int
  -1
end

fun getpid : LibC::Pid
  __lilith_syscall(SC_GETPID, 0).to_int
end

fun abort
  Pointer(LibC::UInt).null.value = 0
  while true
  end
end

fun spawnv(file : LibC::String, argv : UInt8**) : LibC::Pid
  __lilith_syscall(SC_SPAWN, file, strlen(file), Pointer(Void).null, argv)
end

fun spawnxv(s_info : Void*, file : LibC::String, argv : UInt8**) : LibC::Pid
  __lilith_syscall(SC_SPAWN, file, strlen(file), s_info, argv)
end

fun waitpid(pid : LibC::Pid, status : LibC::Int*, options : LibC::Int) : LibC::Pid
  __lilith_syscall(SC_WAITPID, pid.to_usize).to_int
end

fun usleep(timeout : LibC::UInt) : LibC::Int
  __lilith_syscall(SC_SLEEP, timeout.to_usize).to_int
end

fun _sys_time : UInt64
  __lilith_syscall64(SC_TIME, 0.to_usize)
end

# working directory
fun getcwd(str : LibC::String, len : LibC::SizeT) : LibC::String
  if str.null?
    len = __lilith_syscall(SC_GETCWD, 0.to_usize, 0.to_usize).to_int + 1
    retval = LibC::String.malloc len.to_usize
    __lilith_syscall(SC_GETCWD, retval, len.to_usize).to_int
    retval
  else
    __lilith_syscall(SC_GETCWD, str, len).to_int
    str
  end  
end

fun chdir(str : LibC::String) : LibC::Int
  __lilith_syscall(SC_CHDIR, str, strlen(str)).to_int
end

# malloc
fun sbrk(increment : LibC::SizeT) : Void*
  Pointer(Void).new(__lilith_syscall(SC_SBRK, increment).to_u64)
end

# time
fun time(tloc : Void*) : LibC::UInt
  # TODO
  0u32
end

# stat
fun stat(path : LibC::String, statbuf : Void*) : LibC::Int
  # TODO
  -1
end

fun access(path : LibC::String, mode : LibC::Int) : LibC::Int
  # TODO
  -1
end

fun unlink(path : LibC::String) : LibC::Int
  # TODO
  -1
end

fun rename(oldpath : LibC::String, newpath : LibC::String) : LibC::Int
  # TODO
  -1
end
