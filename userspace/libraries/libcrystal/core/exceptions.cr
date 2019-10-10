def abort
  LibC.abort
end

def abort(str)
  # TODO
  abort
end

def raise(*args)
  abort
end

macro unimplemented!(file = __FILE__, line = __LINE__)
  abort "#{file}:#{line}: not implemented"
end
