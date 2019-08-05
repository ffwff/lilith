fun toupper(c : Int32) : Int32
  if c >= 'a'.ord && c <= 'z'.ord
    c = c - 'a'.ord + 'A'.ord
  end
  c
end

fun tolower(c : Int32) : Int32
  if c >= 'A'.ord && c <= 'Z'.ord
    c = c - 'A'.ord + 'a'.ord
  end
  c
end

fun isspace(c : Int32) : Int32
  c = c.unsafe_chr
  (c == ' ' || c == '\t' || c == '\r' || c == '\n') ? 1 : 0
end

fun isprint(c : Int32) : Int32
  (c >= 0x20 && c <= 0x7e) ? 1 : 0
end

fun isdigit(c : Int32) : Int32
  (c >= '0'.ord && c <= '9'.ord) ? 1 : 0
end