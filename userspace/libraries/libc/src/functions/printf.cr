private NULL_STR = "(null)"
private HEX_STR = "0x"
private NINF_STR = "-inf"
private PINF_STR = "inf"
private NNAN_STR = "-nan"
private PNAN_STR = "nan"
private BASE = "0123456789abcdefghijklmnopqrstuvwxyz"

private def printf_int(intg, base = 10)
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

private macro format_int(type, base)
  format += 1
  int = args.next({{ type }})
  str, size = printf_int(int, {{ base }})
  return written if (retval = yield Tuple.new(str.to_unsafe, size.to_i32)) == 0
  written += retval
end

private def internal_gprintf(format : UInt8*, args : VaList, &block)
  written = 0
  while format.value != 0
    if format.value == '%'.ord
      format += 1
      case format.value
      when 0
        return written
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
        format_int(LibC::Int, 10)
      when 'x'.ord
        format_int(LibC::Int, 16)
      when 'o'.ord
        format_int(LibC::Int, 8)
      when 'p'.ord
        return written if (retval = yield str_to_tuple(HEX_STR)) == 0
        written += retval
        format_int(LibC::ULong, 16)
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
        # TODO
      when '0'.ord
        # TODO
      end
    end

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

fun cr_printf(format : UInt8*, ...) : LibC::Int
  VaList.open do |args|
    internal_printf(format, args)
  end
end
