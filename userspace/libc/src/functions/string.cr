fun strlen(str : LibC::String) : LibC::SizeT
  if str.null?
    return 0u32
  end
  i = 0u32
  until str[i] == 0
    i += 1
  end
  i
end

# dup
fun strdup(str : LibC::String) : LibC::String
  if str.null?
    return LibC::String.null
  end
  new_str = calloc(strlen(str) + 1, 1).as(LibC::String)
  strcpy new_str, str
  new_str
end

# cmp
fun strcmp(s1 : LibC::UString, s2 : LibC::UString) : Int32
  while s1.value != 0 && (s1.value == s2.value)
    s1 += 1
    s2 += 1
  end
  (s1.value - s2.value).to_i32
end

fun strncmp(s1 : LibC::UString, s2 : LibC::UString, n : LibC::SizeT) : Int32
  while n > 0 && s1.value != 0 && (s1.value == s2.value)
    s1 += 1
    s2 += 1
    n -= 1
  end
  return 0 if n == 0
  (s1.value - s2.value).to_i32
end

# cpy
fun strcpy(dst : LibC::String, src : LibC::String) : LibC::String
  retval = dst
  until src.value == 0
    dst.value = src.value
    src += 1
    dst += 1
  end
  dst.value = 0
  retval
end

fun strncpy(dst : LibC::String, src : LibC::String, n : LibC::SizeT) : LibC::String
  retval = dst
  until n == 0
    dst.value = src.value
    return retval if src.value == 0
    src += 1
    dst += 1
    n -= 1
  end
  retval
end

# tok
module Strtok
  extend self

  @@saveptr = LibC::String.null

  def saveptr
    pointerof(@@saveptr)
  end

  private def check_delim?(ch, delim : LibC::String)
    until delim.value == 0
      return true if ch == delim.value
      delim += 1
    end
    false
  end
  
  def strtok_r(str : LibC::String, delim : LibC::String, saveptr : LibC::String*) : LibC::String
    arg_begin = str.null? ? saveptr.value : str
    return saveptr.value if str.null? && saveptr.value.null?
    arg = arg_begin
    until arg.value == 0
      if check_delim?(arg.value, delim)
        arg.value = 0
        saveptr.value = arg + 1
        return arg_begin
      end
      arg += 1
    end
    saveptr.value = LibC::String.null
    arg_begin
  end
end

fun strtok(str : LibC::String, delim : LibC::String) : LibC::String
  Strtok.strtok_r(str, delim, Strtok.saveptr)
end

fun strtok_r(str : LibC::String, delim : LibC::String, saveptr : LibC::String*) : LibC::String
  Strtok.strtok_r(str, delim, saveptr)
end

# cat
fun strcat(dst : LibC::String, src : LibC::String) : LibC::String
  ret = dst
  until dst.value == 0
    dst += 1
  end
  while true
    dst.value = src.value
    return ret if src.value == 0
    dst += 1
    src += 1
  end
  ret # unreachable
end

fun strncat(dst : LibC::String, src : LibC::String, n : LibC::SizeT) : LibC::String
  ret = dst
  until dst.value == 0
    dst += 1
  end
  until n == 0
    dst.value = src.value
    return ret if src.value == 0
    dst += 1
    src += 1
    n -= 1
  end
  dst.value = 0
  ret
end

# chr
fun strchr(str : LibC::String, c : Int32) : LibC::String
  until str.value == c
    str += 1
    return LibC::String.null if str.value == 0
  end
  str
end

# memory
fun memset(dst : UInt8*, c : UInt32, n : LibC::SizeT) : Void*
  i = 0
  while i < n
    dst[i] = c.to_u8
    i += 1
  end
  dst.as(Void*)
end

fun memcpy(dst : UInt8*, src : UInt8*, n : LibC::SizeT) : Void*
  i = 0
  while i < n
    dst[i] = src[i]
    i += 1
  end
  dst.as(Void*)
end

fun memmove(dst : UInt8*, src : UInt8*, n : LibC::SizeT) : Void*
  if src.address < dst.address
    src += n.to_i64
    dst += n.to_i64
    until n == 0
      dst.value = src.value
      dst += -1
      src += -1
      n -= 1
    end
  else
    until n == 0
      dst.value = src.value
      dst += 1
      src += 1
      n -= 1
    end
  end
  dst.as(Void*)
end

fun memcmp(s1 : LibC::UString, s2 : LibC::UString, n : LibC::SizeT) : Int32
  while n > 0 && (s1.value == s2.value)
    s1 += 1
    s2 += 1
    n -= 1
  end
  return 0 if n == 0
  (s1.value - s2.value).to_i32
end

fun memchr(str : LibC::String, c : Int32, n : LibC::SizeT) : LibC::String
  until n == 0
    if str.value == c
      return str
    end
    n -= 1
  end
  LibC::String.null
end