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
  (ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n') ? 1 : 0
end

fun isprint(ch : LibC::Int) : LibC::Int
  (ch >= 0x20 && ch <= 0x7e) ? 1 : 0
end

fun isdigit(ch : LibC::Int) : LibC::Int
  (ch >= '0'.ord && ch <= '9'.ord) ? 1 : 0
end

fun islower(ch : LibC::Int) : LibC::Int
  (ch >= 'a'.ord && ch <= 'z'.ord) ? 1 : 0
end

fun isupper(ch : LibC::Int) : LibC::Int
  (ch >= 'A'.ord && ch <= 'Z'.ord) ? 1 : 0
end

fun isalpha(ch : LibC::Int) : LibC::Int
  (islower(ch) == 1 || isupper(ch) == 1) ? 1 : 0
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
  if isalpha(ch)
    1
  elsif isdigit(ch)
    1
  else
    0
  end
end