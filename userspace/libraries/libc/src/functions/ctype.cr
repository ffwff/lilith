fun toupper(ch : LibC::Int) : LibC::Int
  if ch >= 'a'.ord && ch <= 'z'.ord
    ch = ch - 'a'.ord + 'A'.ord
  end
  ch
end

fun tolower(ch : LibC::Int) : LibC::Int
  if ch >= 'A'.ord && ch <= 'Z'.ord
    ch = ch - 'A'.ord + 'a'.ord
  end
  ch
end

fun isspace(ch : LibC::Int) : Bool
  ch = ch.unsafe_chr
  ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n'
end

fun isprint(ch : LibC::Int) : Bool
  ch >= 0x20 && ch <= 0x7e
end

fun isdigit(ch : LibC::Int) : Bool
  ch >= '0'.ord && ch <= '9'.ord
end

fun islower(ch : LibC::Int) : Bool
  ch >= 'a'.ord && ch <= 'z'.ord
end

fun isupper(ch : LibC::Int) : Bool
  ch >= 'A'.ord && ch <= 'Z'.ord
end

fun isalpha(ch : LibC::Int) : Bool
  islower(ch) || isupper(ch)
end

fun isgraph(ch : LibC::Int) : LibC::Int
  # TODO
  abort
  0
end

fun ispunct(ch : LibC::Int) : LibC::Int
  # TODO
  abort
  0
end

fun iscntrl(ch : LibC::Int) : LibC::Int
  # TODO
  abort
  0
end

fun isxdigit(ch : LibC::Int) : LibC::Int
  # TODO
  abort
  0
end

fun isalnum(ch : LibC::Int) : Bool
  isalpha(ch) || isdigit(ch)
end