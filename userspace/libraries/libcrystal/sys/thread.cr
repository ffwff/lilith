lib LibC
  fun usleep(timeout : UInt64) : LibC::Int
  fun exit(code : LibC::Int) : NoReturn
end

def usleep(usecs : Int)
  LibC.usleep usecs.to_u64
end

def sleep(seconds : Int)
  usecs = seconds.to_u64 * 1000000
  LibC.usleep usecs
end

def exit(code : Int)
  STDOUT.flush
  LibC.exit code
end
