TIOCGWINSZ = 0

lib LibC
  struct SyscallIoctlArgument
    request : LibC::Int
    data    : Void*
  end
end

fun ioctl(fd : LibC::Int, request : LibC::Int, data : Void*) : LibC::Int
  arg = uninitialized LibC::SyscallIoctlArgument
  arg.request = request
  arg.data = data
  sysenter(SC_IOCTL, fd, pointerof(arg).address.to_u32).to_i32
end