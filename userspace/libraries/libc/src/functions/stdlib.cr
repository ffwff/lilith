private def parse_float(str : UInt8*, &block) : UInt8*
  dec = 0
  frac = 0
  frac_divider = 1
  sign = 1
  while isspace(str.value.to_int) == 1
    str += 1
  end
  if str.value == '+'.ord
  elsif str.value == '-'.ord
    sign = -1
  elsif isdigit(str.value.to_int) == 1
    dec = (str.value - '0'.ord).to_i32
  else
    return str
  end
  while (ch = str.value) != 0
    if isdigit(ch.to_int) == 1
      str += 1
      digit = ch - '0'.ord
      dec = dec * 10 + digit
    elsif ch == '.'.ord
      str += 1
      # fractional part
      while (ch = str.value) != 0
        if isdigit(ch.to_int) == 1
          digit = ch - '0'.ord
          frac = frac * 10 + digit
          frac_divider *= 10
        else
          break
        end
      end
      yield Tuple.new(sign, dec, frac, frac_divider)
      return str
    else
      break
    end
  end
  str
end

fun strtof(nptr : UInt8*, endptr : UInt8**) : Float32
  retval = 0.0f32
  retptr = parse_float(nptr) do |sign, dec, frac, frac_divider|
    retval = sign.to_f32 * (dec.to_f32 + frac.to_f32 / frac_divider.to_f32)
  end
  unless endptr.null?
    endptr.value = retptr
  end
  retval
end

fun strtod(nptr : UInt8*, endptr : UInt8**) : Float64
  retval = 0.0f64
  retptr = parse_float(nptr) do |sign, dec, frac, frac_divider|
    retval = sign.to_f64 * (dec.to_f64 + frac.to_f64 / frac_divider.to_f64)
  end
  unless endptr.null?
    endptr.value = retptr
  end
  retval
end

fun atof(nptr : UInt8*) : Float64
  retval = 0.0f64
  parse_float(nptr) do |sign, dec, frac, frac_divider|
    retval = sign.to_f64 * (dec.to_f64 + frac.to_f64 / frac_divider.to_f64)
  end
  retval
end

private def parse_int(str : UInt8*, &block) : UInt8*
  sign = 0
  num = 0u64
  while isspace(str.value.to_int) == 1
    str += 1
  end
  if str.value == '+'.ord
  elsif str.value == '-'.ord
    sign = -1
  elsif isdigit(str.value.to_int) == 1
    dec = (str.value - '0'.ord).to_i32
  else
    return str
  end
  while (ch = str.value) != 0
    if isdigit(ch.to_int) == 1
      str += 1
      digit = ch - '0'.ord
      num = num * 10 + digit
    else
      break
    end
  end
  yield Tuple.new(sign, num)
  str
end

fun strtol(nptr : UInt8*, endptr : UInt8**, base : LibC::Int) : LibC::Long
  retval = 0.to_long
  retptr = parse_int(nptr) do |sign, num|
    retval = sign.to_long * num.to_long
  end
  unless endptr.null?
    endptr.value = retptr
  end
  retval
end

fun strtoul(nptr : UInt8*, endptr : UInt8**, base : LibC::Int) : LibC::ULong
  retval = 0.to_ulong
  retptr = parse_int(nptr) do |sign, num|
    retval = num.to_ulong
  end
  unless endptr.null?
    endptr.value = retptr
  end
  retval
end

fun atoi(nptr : UInt8*) : LibC::Int
  retval = 0
  parse_int(nptr) do |sign, num|
    retval = sign * num
  end
  retval
end

fun atol(nptr : UInt8*) : LibC::Long
  retval = 0.to_long
  parse_int(nptr) do |sign, num|
    retval = sign.to_long * num.to_long
  end
  retval
end

fun abs(j : LibC::Int) : LibC::Int
  j > 0 ? j : (j * -1)
end

fun labs(j : LibC::Long) : LibC::Long
  j > 0 ? j : (j * -1)
end

fun llabs(j : LibC::LongLong) : LibC::LongLong
  j > 0 ? j : (j * -1)
end
