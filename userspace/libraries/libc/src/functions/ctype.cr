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

fun isspace(ch : LibC::Int) : LibC::Int
  ch = ch.unsafe_chr
  (ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n').to_int
end

fun isprint(ch : LibC::Int) : LibC::Int
  (ch >= 0x20 && ch <= 0x7e).to_int
end

fun isdigit(ch : LibC::Int) : LibC::Int
  (ch >= '0'.ord && ch <= '9'.ord).to_int
end

fun islower(ch : LibC::Int) : LibC::Int
  (ch >= 'a'.ord && ch <= 'z'.ord).to_int
end

fun isupper(ch : LibC::Int) : LibC::Int
  (ch >= 'A'.ord && ch <= 'Z'.ord).to_int
end

fun isalpha(ch : LibC::Int) : LibC::Int
  (islower(ch) == 1 || isupper(ch) == 1).to_int
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

fun isalnum(ch : LibC::Int) : LibC::Int
  (isalpha(ch) == 1 || isdigit(ch) == 1).to_int
end
