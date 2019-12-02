private NULL_STR = "(null)"
private HEX_STR = "0x"
private NINF_STR = "-inf"
private PINF_STR = "inf"
private NNAN_STR = "-nan"
private PNAN_STR = "nan"
private BASE = "0123456789abcdefghijklmnopqrstuvwxyz"

def printf_int(intg, base = 10)
  s = uninitialized UInt8[128]
  sign = intg < 0
  n = intg < 0 ? (intg * -1) : intg
  len = 0
  while len < s.size
    s[len] = BASE.to_unsafe[n % base]
    len += 1
    break if (n //= base) == 0
  end
  if sign
    s[len] = '-'.ord.to_u8
  else
    len -= 1
  end
  i = 0
  j = len
  while i < j
    c = s[i]
    s[i] = s[j]
    s[j] = c
    i += 1
    j -= 1
  end
  Tuple.new(s, len + 1)
end

private def str_to_tuple(str : String)
  Tuple.new(str.to_unsafe, str.size)
end

private macro format_num(type, base)
  format += 1
  int = args.next({{ type }})
  str, size = printf_int(int, {{ base }})
  if pad_field > 0 && size < pad_field
    zeroes = uninitialized UInt8[64]
    pad_width = pad_field - size
    abort if pad_width > 64
    pad_width.times do |w|
      zeroes[w] = '0'.ord.to_u8
    end
    return written if (retval = yield Tuple.new(zeroes.to_unsafe, pad_width.to_i32)) == 0
    written += retval
  end
  return written if (retval = yield Tuple.new(str.to_unsafe, size.to_i32)) == 0
  written += retval
end

private macro format_int(base)
  case length_field
  when LengthField::Long
    format_num(LibC::Long, {{ base }})
  when LengthField::LongLong
    format_num(LibC::LongLong, {{base}})
  else
    format_num(LibC::Int, {{base}})
  end
end

private enum LengthField
  None
  Long
  LongLong
  LongDouble
end

private def internal_gprintf(format : UInt8*, args : VaList, &block)
  written = 0
  field_parsed = false
  length_field = LengthField::None
  pad_field = 0
  until format.value == 0
    if format.value == '%'.ord || field_parsed
      if field_parsed
        field_parsed = false
      else
        format += 1
      end
      case format.value
      when 0
        return written
      when '%'.ord
        format += 1
        return written if (retval = yield '%') == 0
        written += retval
      when 'c'.ord
        format += 1
        ch = args.next(LibC::Int)
        return written if (retval = yield ch.unsafe_chr) == 0
        written += retval
      when 's'.ord
        format += 1
        str = args.next(Pointer(UInt8))
        if str.address == 0
          return written if (retval = yield str_to_tuple(NULL_STR)) == 0
        else
          return written if (retval = yield Tuple.new(str, strlen(str).to_i32)) == 0
        end
        written += retval
      when 'd'.ord
        format_int(10)
      when 'x'.ord
        format_int(16)
      when 'o'.ord
        format_int(8)
      when 'p'.ord
        return written if (retval = yield str_to_tuple(HEX_STR)) == 0
        written += retval
        format_num(LibC::ULong, 16)
      when 'f'.ord
        format += 1

        float = args.next(Float64)
        bits = float.unsafe_as(UInt64)
        fraction = bits & 0xfffffffffffffu64
        exponent = (bits >> 52) & 0x7ffu64

        if exponent == 0x7FF
          # special values
          if fraction == 0 # inf
            str = (bits & (1 << 53)) != 0 ? NINF_STR : PINF_STR
            return written if (retval = yield str_to_tuple(str)) == 0
          else # nan
            str = (bits & (1 << 53)) != 0 ? NNAN_STR : PNAN_STR
            return written if (retval = yield str_to_tuple(str)) == 0
          end
          written += retval
          next
        else
          # numeric values
          decimal = float.to_i64
          fractional = ((float - decimal) * 100000000).to_i64

          str, size = printf_int(decimal)
          return written if (retval = yield Tuple.new(str.to_unsafe, size.to_i32)) == 0
          written += retval

          return written if (retval = yield '.') == 0
          written += retval

          str, size = printf_int(fractional)
          return written if (retval = yield Tuple.new(str.to_unsafe, size.to_i32)) == 0
          written += retval
        end
      when 'l'.ord
        format += 1
        case length_field
        when LengthField::None
          length_field = LengthField::Long
        when LengthField::Long
          length_field = LengthField::LongLong
        end
        field_parsed = true
        next
      when '0'.ord
        format += 1
        while format.value >= '0'.ord && format.value <= '9'.ord
          pad_field = pad_field * 10 + (format.value - '0'.ord)
          format += 1
        end
        if pad_field > 64
          pad_field = 64
        end
        field_parsed = true
        next
      end
    end

    # reset all fields
    length_field = LengthField::None
    pad_field = 0

    format_start = format
    amount = 0
    while format.value != 0
      break if format.value == '%'.ord
      amount += 1
      format += 1
    end
    if amount > 0
      return written if (retval = yield Tuple.new(format_start, amount)) == 0
      written += retval
    end
  end
  written
end

private def internal_printf(format : UInt8*, args : VaList)
  internal_gprintf(format, args) do |value|
    case value
    when Char
      # TODO: multibyte char
      putchar value.ord
    when Tuple(UInt8*, Int32)
      str, size = value
      nputs str, size.to_usize
    else
      Stdio.stderr.fputs "unhandled type\n"
      abort
    end
  end
end

private def internal_fprintf(file : Void*, format : UInt8*, args : VaList)
  internal_gprintf(format, args) do |value|
    case value
    when Char
      # TODO: multibyte char
      fputc value.ord, file
    when Tuple(UInt8*, Int32)
      str, size = value
      fnputs str, size.to_usize, file
    else
      Stdio.stderr.fputs "unhandled type\n"
      abort
    end
  end
end

# pass limit=-1 for snprintf return behavior
private def internal_snprintf(buf : UInt8*, limit : Int, format : UInt8*, args : VaList)
  written = 0
  internal_gprintf(format, args) do |value|
    case value
    when Char
      # TODO: multibyte char
      if limit == -1
        written += 1
      elsif limit > 0
        buf[0] = value.ord.to_u8
        buf += 1
        written += 1
        limit -= 1
      end
      1
    when Tuple(UInt8*, Int32)
      str, size = value
      if limit == -1
        written += size
      elsif limit > 0
        size = Math.min(size, limit)
        strncpy buf, str, size.to_usize
        buf += size
        written += size
        limit -= size
      end
      size
    else
      Stdio.stderr.fputs "unhandled type\n"
      abort
    end
  end
  written
end

fun printf(format : UInt8*, ...) : LibC::Int
  VaList.open do |args|
    internal_printf(format, args)
  end
end

fun fprintf(stream : Void*, format : UInt8*, ...) : LibC::Int
  VaList.open do |args|
    internal_fprintf(stream, format, args)
  end
end

fun snprintf(str : UInt8*, size : LibC::SizeT, format : UInt8*, ...) : LibC::Int
  VaList.open do |args|
    internal_snprintf(str, size, format, args)
  end
end

fun sprintf(str : UInt8*, format : UInt8*, ...) : LibC::Int
  VaList.open do |args|
    internal_snprintf(str, -1, format, args)
  end
end

fun __libc_vprintf(format : UInt8*, ap : LibC::VaList*): LibC::Int
  VaList.copy(ap) do |args|
    internal_printf(format, args)
  end
end

fun __libc_vfprintf(stream : Void*, format : UInt8*, ap : LibC::VaList*): LibC::Int
  VaList.copy(ap) do |args|
    internal_fprintf(stream, format, args)
  end
end

fun __libc_vsnprintf(str : UInt8*, size : LibC::SizeT, format : UInt8*, ap : LibC::VaList*): LibC::Int
  VaList.copy(ap) do |args|
    internal_snprintf(str, size, format, args)
  end
end

fun __libc_vsprintf(str : UInt8*, format : UInt8*, ap : LibC::VaList*): LibC::Int
  VaList.copy(ap) do |args|
    internal_snprintf(str, -1, format, args)
  end
end
