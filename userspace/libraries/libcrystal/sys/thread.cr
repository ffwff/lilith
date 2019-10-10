lib LibC
  fun usleep(timeout : LibC::UInt)
  fun exit(code : LibC::Int) : NoReturn
end

def sleep(seconds : Int)
  usecs = seconds.to_uint * 1000
  LibC.usleep usecs
end

def exit(code)
  LibC.exit code
end
