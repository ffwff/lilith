TIOCGWINSZ = 0

lib LibC
  struct SyscallIoctlArgument
    request : Int32
    data    : Void*
  end
end

fun ioctl(fd : Int32, request : Int32, data : Void*) : Int32
  arg = uninitialized LibC::SyscallIoctlArgument
  arg.request = request
  arg.data = data
  sysenter(SC_IOCTL, fd, pointerof(arg).address.to_u32).to_i32
end