def abort
  LibC.abort
end

def abort(str : String)
  LibC.fprintf(LibC.stderr, "%s", str)
  abort
end

def raise(*args)
  abort
end

fun __crystal_raise_overflow : NoReturn
  abort "overflow detected"
end

fun __crystal_personality
end

fun __crystal_raise(unwind_ex : Void*)
  abort "__crystal_raise called"
end

fun __crystal_get_exception(unwind_ex : Void*) : UInt64
  0u64
end

macro unimplemented(file = __FILE__, line = __LINE__)
  abort "{{ file }}:{{ line }}: not implemented"
end
