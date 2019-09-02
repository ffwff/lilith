require "../syscall_defs.cr"

lib LibC
  struct SyscallStringArgument
    str : String
    len : LibC::UInt
  end

  struct SyscallSeekArgument
    offset : LibC::Int
    whence : LibC::Int
  end

  fun sysenter(eax : LibC::UInt, ebx : LibC::UInt, edx : LibC::UInt) : LibC::UInt
end

@[AlwaysInline]
def sysenter(eax, ebx, edx)
  LibC.sysenter eax, ebx, edx
end

@[AlwaysInline]
def sysenter(eax, ebx)
  LibC.sysenter eax, ebx, 0
end

# IO
fun _open(device : LibC::String, flags : LibC::Int) : LibC::Int
  buf = uninitialized LibC::SyscallStringArgument
  buf.str = device
  buf.len = strlen(device)
  sysenter(SC_OPEN, pointerof(buf).address.to_u32, flags).to_i32
end

fun create(device : LibC::String) : LibC::Int
  buf = uninitialized LibC::SyscallStringArgument
  buf.str = device
  buf.len = strlen(device)
  sysenter(SC_CREATE, pointerof(buf).address.to_u32, 0).to_i32
end

fun close(fd : LibC::Int) : LibC::Int
  sysenter(SC_CLOSE, fd.to_u32).to_i32
end

fun write(fd : LibC::Int, str : LibC::String, len : LibC::Int) : LibC::Int
  buf = uninitialized LibC::SyscallStringArgument
  buf.str = str
  buf.len = len
  sysenter(SC_WRITE, fd, pointerof(buf).address.to_u32).to_i32
end

fun read(fd : LibC::Int, str : LibC::String, len : LibC::Int) : LibC::Int
  buf = uninitialized LibC::SyscallStringArgument
  buf.str = str
  buf.len = len
  sysenter(SC_READ, fd, pointerof(buf).address.to_u32).to_i32
end

fun ftruncate(fd : LibC::Int, length : LibC::UInt) : LibC::Int
  sysenter(SC_TRUNCATE, fd, length).to_i32
end

fun waitfd(fd : LibC::Int, timeout : LibC::ULong) : LibC::Int
  sysenter(SC_WAITFD, fd, timeout).to_i32
end

fun remove(str : LibC::String) : LibC::Int
  -1
end

fun lseek(fd : LibC::Int, offset : Int32, whence : LibC::Int) : Int32
  arg = uninitialized LibC::SyscallSeekArgument
  arg.offset = offset
  arg.whence = whence
  sysenter(SC_SEEK, fd, pointerof(arg).address.to_u32).to_i32
end

fun lseek64(fd : LibC::Int, offset : Int64, whence : LibC::Int) : Int64
  (-1).to_i64
end

# process
fun _exit : Nil
  sysenter(SC_EXIT, 0)
end

fun raise(sig : LibC::Int) : LibC::Int
  -1
end

fun abort
  Pointer(LibC::UInt).null.value = 0
  while true
  end
end

fun spawnv(file : LibC::String, argv : UInt8**) : LibC::Pid
  buf = uninitialized LibC::SyscallStringArgument
  buf.str = file
  buf.len = strlen(file)
  sysenter(SC_SPAWN, pointerof(buf).address.to_u32, argv.address.to_u32).to_i32
end

fun waitpid(pid : LibC::Pid, status : LibC::Int*, options : LibC::Int) : LibC::Pid
  sysenter(SC_WAITPID, pid, 0).to_i32
end

fun usleep(timeout : LibC::ULong) : LibC::Int
  sysenter(SC_SLEEP, timeout).to_i32
end

# working directory
fun getcwd(str : LibC::String, len : LibC::Int) : LibC::Int
  buf = uninitialized LibC::SyscallStringArgument
  buf.str = str
  buf.len = len
  sysenter(SC_GETCWD, pointerof(buf).address.to_u32).to_i32
end

fun chdir(str : LibC::String) : LibC::Int
  buf = uninitialized LibC::SyscallStringArgument
  buf.str = str
  buf.len = strlen(str)
  sysenter(SC_CHDIR, pointerof(buf).address.to_u32).to_i32
end

# malloc
fun sbrk(increment : LibC::UInt) : Void*
  Pointer(Void).new(sysenter(SC_SBRK, increment).to_u64)
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