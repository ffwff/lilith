PIPE_PREFIX = "/pipes/"

fun mkpipe(name : LibC::String) : LibC::Int
  nsize = strlen(name)
  return -1 if nsize < 1
  psize = PIPE_PREFIX.size + nsize

  # create path  
  path = uninitialized UInt8[SC_PATH_MAX]
  PIPE_PREFIX.size.times do |i|
    path.to_unsafe[i] = PIPE_PREFIX.to_unsafe[i]
  end
  path.to_unsafe[PIPE_PREFIX.size] = 0u8
  strcpy((path.to_unsafe + PIPE_PREFIX.size).as(LibC::String), name.as(LibC::String))
  fd = create(path.to_unsafe.as(LibC::String))
  fd
end

fun mkfpipe(name : LibC::String, flags : LibC::UInt) : LibC::Int
  fd = mkpipe(name)
  return fd if fd < 0
  _ioctl(fd, SC_IOCTL_PIPE_CONF_FLAGS, flags)
  fd
end

fun mkppipe(name : LibC::String, flags : LibC::UInt, pid : LibC::Pid) : LibC::Int
  fd = mkpipe(name)
  return fd if fd < 0
  _ioctl(fd, SC_IOCTL_PIPE_CONF_FLAGS, flags)
  _ioctl(fd, SC_IOCTL_PIPE_CONF_PID, pid.to_uint)
  fd
end
