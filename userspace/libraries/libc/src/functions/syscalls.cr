require "../syscall_defs.cr"

# sysenter implementations
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
private def __lilith_syscall(eax : UInt32, fd : Int32) : Int32
  __lilith_syscall(eax, fd.to_u32)
end

@[AlwaysInline]
private def __lilith_syscall(eax : UInt32,
                             str : LibC::String,
                             len : UInt32,
                             flag : Int32 = 0)
  __lilith_syscall(eax, str.address.to_u32, len, flag.to_u32)
end

@[AlwaysInline]
private def __lilith_syscall(eax : UInt32,
                             fd : Int32,
                             str : LibC::String,
                             len : Int32)
  __lilith_syscall(eax, fd.to_u32, str.address.to_u32, len.to_u32)
end

@[AlwaysInline]
private def __lilith_syscall(eax : UInt32,
                             fd : Int32,
                             generic : Void*)
  __lilith_syscall(eax, fd.to_u32, generic.address.to_u32)
end

@[AlwaysInline]
private def __lilith_syscall(eax : UInt32,
                             str : LibC::String,
                             len : UInt32,
                             s_info : Void*,
                             argv : UInt8**)
  __lilith_syscall(eax, str.address.to_u32, len, s_info.address.to_u32, argv.address.to_u32)
end

# IO
fun _open(device : LibC::String, flags : LibC::Int) : LibC::Int
  __lilith_syscall(SC_OPEN, device, strlen(device), flags)
end

fun create(device : LibC::String) : LibC::Int
  __lilith_syscall(SC_CREATE, device, strlen(device))
end

fun close(fd : LibC::Int) : LibC::Int
  __lilith_syscall(SC_CLOSE, fd).to_int
end

fun read(fd : LibC::Int, str : LibC::String, len : LibC::Int) : LibC::Int
  __lilith_syscall(SC_READ, fd, str, len).to_int
end

fun write(fd : LibC::Int, str : LibC::String, len : LibC::Int) : LibC::Int
  __lilith_syscall(SC_WRITE, fd, str, len).to_int
end

fun ftruncate(fd : LibC::Int, length : LibC::Int) : LibC::Int
  __lilith_syscall(SC_TRUNCATE, fd.to_u32, length.to_u32).to_int
end

fun lseek(fd : LibC::Int, offset : Int32, whence : LibC::Int) : Int32
  __lilith_syscall(SC_SEEK, fd.to_u32, offset.to_u32, whence.to_u32).to_int
end

fun lseek64(fd : LibC::Int, offset : Int64, whence : LibC::Int) : Int64
  (-1).to_i64
end

fun _ioctl(fd : LibC::Int, request : LibC::Int, data : UInt32) : LibC::Int
  __lilith_syscall(SC_IOCTL, fd.to_u32, request.to_u32, data.to_u32).to_int
end

fun waitfd(fd : LibC::Int, timeout : LibC::UInt) : LibC::Int
  __lilith_syscall(SC_WAITFD, fd.to_u32, timeout.to_u32).to_int
end

fun remove(str : LibC::String) : LibC::Int
  __lilith_syscall(SC_REMOVE, str, strlen(str)).to_int
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

fun getpid : LibC::Int
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
  __lilith_syscall(SC_WAITPID, pid.to_u32).to_int
end

fun usleep(timeout : LibC::UInt) : LibC::Int
  __lilith_syscall(SC_SLEEP, timeout).to_int
end

# working directory
fun getcwd(str : LibC::String, len : LibC::Int) : LibC::Int
  __lilith_syscall(SC_GETCWD, str, len.to_u32).to_int
end

fun chdir(str : LibC::String) : LibC::Int
  __lilith_syscall(SC_GETCWD, str, strlen(str)).to_int
end

# malloc
fun sbrk(increment : LibC::UInt) : Void*
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
