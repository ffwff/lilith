require "../syscall_defs.cr"

lib LibC
  struct SyscallStringArgument
    str : String
    len : UInt32
  end

  fun sysenter(eax : UInt32, ebx : UInt32, edx : UInt32) : UInt32
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
fun _open(device : LibC::String, flags : Int32, mode : UInt32) : Int32
  sysenter(SC_OPEN, device.address.to_u32, flags).to_i32
end

fun close(fd : Int32) : Int32
  sysenter(SC_CLOSE, fd.to_u32).to_i32
end

fun write(fd : Int32, str : LibC::String, len : Int32) : Int32
  buf = uninitialized LibC::SyscallStringArgument
  buf.str = str
  buf.len = len
  sysenter(SC_WRITE, fd, pointerof(buf).address.to_u32).to_i32
end

fun read(fd : Int32, str : LibC::String, len : Int32) : Int32
  buf = uninitialized LibC::SyscallStringArgument
  buf.str = str
  buf.len = len
  sysenter(SC_READ, fd, pointerof(buf).address.to_u32).to_i32
end

fun remove(str : LibC::String) : Int32
  -1
end

fun lseek64(fd : Int32, offset : Int64, whence : Int32) : Int64
  (-1).to_i64
end

# process
fun _exit : Nil
  sysenter(SC_EXIT, 0)
end

fun raise(sig : Int32) : Int32
  -1
end

fun abort
  Pointer(UInt32).null.value = 0
  while true
  end
end

fun spawnv(file : LibC::String, argv : UInt8**) : LibC::Pid
  sysenter(SC_SPAWN, file.address.to_u32, argv.address.to_u32).to_i32
end

fun waitpid(pid : LibC::Pid, status : Int32*, options : Int32) : LibC::Pid
  sysenter(SC_WAITPID, pid, 0).to_i32
end

# working directory
fun getcwd(str : LibC::String, len : Int32) : Int32
  buf = uninitialized LibC::SyscallStringArgument
  buf.str = str
  buf.len = len
  sysenter(SC_GETCWD, pointerof(buf).address.to_u32).to_i32
end

fun chdir(str : LibC::String) : Int32
  sysenter(SC_CHDIR, str.address.to_u32).to_i32
end

# malloc
fun sbrk(increment : UInt32) : Void*
  Pointer(Void).new(sysenter(SC_SBRK, increment).to_u64)
end

# time
fun time(tloc : Void*) : UInt32
  0u32
end