def abort
  LibC.abort
end

def abort(str)
  STDERR.puts str
  abort
end

def raise(*args)
  abort
end

macro unimplemented!(file = __FILE__, line = __LINE__)
  abort "not implemented"
end
