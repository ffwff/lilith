lib LibC
  fun fprintf(stream : Void*, x0 : LibC::UString, ...) : LibC::Int
  $stderr : Void*
end

def abort
  LibC.abort
end

def abort(str)
  LibC.fprintf(LibC.stderr, "%s", str)
  abort
end

def raise(*args)
  abort
end

fun __crystal_raise_overflow : NoReturn
  abort "overflow detected"
end

macro unimplemented!(file = __FILE__, line = __LINE__)
  abort "not implemented"
end
