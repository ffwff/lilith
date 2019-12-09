# string->float conversion
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
  strtod nptr, Pointer(UInt8*).null
end

# string->int conversion
fun strtol(nptr : UInt8*, endptr : UInt8**, base : LibC::Int) : LibC::Long
  abort
  0.to_long
end

fun strtoul(nptr : UInt8*, endptr : UInt8**, base : LibC::Int) : LibC::ULong
  abort
  0.to_ulong
end

fun atoi(nptr : UInt8*) : LibC::Int
  abort
  0
end

fun atol(nptr : UInt8*) : LibC::Long
  abort
  0.to_long
end

# environ
fun getenv(name : UInt8*) : UInt8*
  Pointer(UInt8).null
end

fun setenv(name : UInt8*, value : UInt8*, overwrite : LibC::Int) : LibC::Int
  0
end

# rand
fun rand : LibC::Int
  # TODO: chosen by an fair dice roll
  # guaranteed to be random
  4
end

# abs
fun abs(j : LibC::Int) : LibC::Int
  j > 0 ? j : (j * -1)
end

fun labs(j : LibC::Long) : LibC::Long
  j > 0 ? j : (j * -1)
end

fun llabs(j : LibC::LongLong) : LibC::LongLong
  j > 0 ? j : (j * -1)
end

# spawn
fun system(command : UInt8*) : LibC::Int
  0
end
