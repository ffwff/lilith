lib LibC
  fun usleep(timeout : LibC::UInt) : LibC::Int
  fun exit(code : LibC::Int) : NoReturn
end

def usleep(usecs)
  LibC.usleep usecs.to_uint
end

def sleep(seconds)
  usecs = seconds.to_uint * 1000000
  LibC.usleep usecs
end

def exit(code)
  LibC.exit code
end
