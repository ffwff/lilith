fun strlen(str : UInt8*) : LibC::SizeT
  if str.null?
    return 0.to_usize
  end
  i = 0.to_usize
  until str[i] == 0
    i += 1
  end
  i
end

# dup
fun strdup(str : UInt8*) : UInt8*
  if str.null?
    return Pointer(UInt8).null
  end
  new_str = calloc(strlen(str) + 1, 1).as(UInt8*)
  strcpy new_str, str
  new_str
end

# cmp
fun strcmp(s1 : UInt8*, s2 : UInt8*) : LibC::Int
  while s1.value != 0 && (s1.value == s2.value)
    s1 += 1
    s2 += 1
  end
  (s1.value - s2.value).to_int
end

fun strncmp(s1 : UInt8*, s2 : UInt8*, n : LibC::SizeT) : LibC::Int
  while n > 0 && s1.value != 0 && (s1.value == s2.value)
    s1 += 1
    s2 += 1
    n -= 1
  end
  return 0 if n == 0
  (s1.value - s2.value).to_int
end

# cpy
fun strcpy(dst : UInt8*, src : UInt8*) : UInt8*
  retval = dst
  until src.value == 0
    dst.value = src.value
    src += 1
    dst += 1
  end
  dst.value = 0
  retval
end

fun strncpy(dst : UInt8*, src : UInt8*, n : LibC::SizeT) : UInt8*
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
private module Strtok
  extend self

  @@saveptr = Pointer(UInt8).null

  def saveptr
    pointerof(@@saveptr)
  end

  private def check_delim?(ch, delim : UInt8*)
    until delim.value == 0
      return true if ch == delim.value
      delim += 1
    end
    false
  end

  def strtok_r(str : UInt8*, delim : UInt8*, saveptr : UInt8**) : UInt8*
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
    saveptr.value = Pointer(UInt8).null
    arg_begin
  end
end

fun strtok(str : UInt8*, delim : UInt8*) : UInt8*
  Strtok.strtok_r(str, delim, Strtok.saveptr)
end

fun strtok_r(str : UInt8*, delim : UInt8*, saveptr : UInt8**) : UInt8*
  Strtok.strtok_r(str, delim, saveptr)
end

# cat
fun strcat(dst : UInt8*, src : UInt8*) : UInt8*
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

fun strncat(dst : UInt8*, src : UInt8*, n : LibC::SizeT) : UInt8*
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
fun strchr(str : UInt8*, c : LibC::Int) : UInt8*
  until str.value == c
    return Pointer(UInt8).null if str.value == 0
    str += 1
  end
  str
end

fun strrchr(str : UInt8*, c : LibC::Int) : UInt8*
  retval = Pointer(UInt8).null
  until str.value == 0
    if str.value == c.to_u8
      retval = str
    end
    str += 1
  end
  retval
end

# pbrk
fun strpbrk(s1 : UInt8*, s2 : UInt8*) : UInt8*
  until s1.value == 0
    return s1 if strchr(s2, s1.value.to_int)
    s1 += 1
  end
  Pointer(UInt8).null
end

# spn
fun strspn(s1 : UInt8*, s2 : UInt8*) : LibC::SizeT
  ret = 0.to_usize
  while s1.value != 0 && strchr(s2, s1.value.to_int)
    s1 += 1
    ret += 1
  end
  ret
end

# str
fun strstr(s1 : UInt8*, s2 : UInt8*) : UInt8*
  n = strlen s2.as(UInt8*)
  until s1.value == 0
    if memcmp(s1, s2, n) == 0
      return s1
    end
    s1 += 1
  end
  Pointer(UInt8).null
end

# memory
fun memset(dst : UInt8*, c : LibC::UInt, n : LibC::SizeT) : Void*
  r0 = r1 = r2 = 0
  asm(
    "cld\nrep stosb"
          : "={al}"(r0), "={Di}"(r1), "={cx}"(r2)
          : "{al}"(c.to_u8), "{Di}"(dst), "{cx}"(n)
          : "volatile", "memory"
  )
  dst.as(Void*)
end

fun memcpy(dst : UInt8*, src : UInt8*, n : LibC::SizeT) : Void*
  r0 = r1 = r2 = 0
  asm(
    "cld\nrep movsb"
          : "={Di}"(r0), "={Si}"(r1), "={cx}"(r2)
          : "{Di}"(dst), "{Si}"(src), "{cx}"(n)
          : "volatile", "memory"
  )
  dst.as(Void*)
end

fun memmove(dst : UInt8*, src : UInt8*, n : LibC::SizeT) : Void*
  if src.address < dst.address
    src += n.to_i64
    dst += n.to_i64
    until n == 0
      dst -= 1
      src -= 1
      dst.value = src.value
      n -= 1
    end
  else
    memcpy dst, src, n
  end
  dst.as(Void*)
end

fun memcmp(s1 : UInt8*, s2 : UInt8*, n : LibC::SizeT) : LibC::Int
  while n > 0 && (s1.value == s2.value)
    s1 += 1
    s2 += 1
    n -= 1
  end
  return 0 if n == 0
  (s1.value - s2.value).to_int
end

fun memchr(str : UInt8*, c : LibC::Int, n : LibC::SizeT) : UInt8*
  until n == 0
    str += 1
    if str.value == c
      return str
    end
    n -= 1
  end
  Pointer(UInt8).null
end

# errors
fun strerror(errnum : LibC::Int) : UInt8*
  Pointer(UInt8).null
end
