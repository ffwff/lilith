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

fun isgraph(ch : LibC::Int) : LibC::Int
  # TODO
  abort
  0
end