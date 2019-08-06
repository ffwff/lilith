fun toupper(ch : Int32) : Int32
  if ch >= 'a'.ord && ch <= 'z'.ord
    ch = ch - 'a'.ord + 'A'.ord
  end
  ch
end

fun tolower(ch : Int32) : Int32
  if ch >= 'A'.ord && ch <= 'Z'.ord
    ch = ch - 'A'.ord + 'a'.ord
  end
  ch
end

fun isspace(ch : Int32) : Int32
  ch = ch.unsafe_chr
  (ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n') ? 1 : 0
end

fun isprint(ch : Int32) : Int32
  (ch >= 0x20 && ch <= 0x7e) ? 1 : 0
end

fun isdigit(ch : Int32) : Int32
  (ch >= '0'.ord && ch <= '9'.ord) ? 1 : 0
end