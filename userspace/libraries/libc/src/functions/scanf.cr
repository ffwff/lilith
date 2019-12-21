private enum ScanfReq
  Getc
  Ungetc
end

private def internal_gscanf(format : UInt8*, args : VaList, &block)
  read_bytes = 0
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
        return read_bytes
      when '%'.ord
        format += 1
        return read_bytes if '%'.ord != yield ScanfReq::Getc
        read_bytes == 1
      when 'c'.ord
        format += 1
        chp = args.next(Pointer(UInt8))
        if (ch = yield ScanfReq::Getc)
          chp.value = ch.to_u8
        else
          return read_bytes
        end
        read_bytes += 1
      when 's'.ord
        format += 1
        # TODO: implement me
        abort
      when 'd'.ord
        format += 1
        num = 0
        sign = 1

        # read first byte
        case (ch = yield ScanfReq::Getc)
        when '+'.ord
        when '-'.ord
          sign = -1
        else
          if isdigit(ch.to_int) == 1
            num = (ch - '0'.ord).to_int
          else
            return read_bytes
          end
        end
        read_bytes += 1

        # read some digits
        while (ch = yield ScanfReq::Getc)
          if isdigit(ch.to_int) == 1
            digit = ch - '0'.ord
            num = num * 10 + digit
          else
            yield ScanfReq::Ungetc
            break
          end
          read_bytes += 1
        end

        num *= sign
        intptr = args.next(Pointer(LibC::Int))
        intptr.value = num
      when 'f'.ord
        format += 1

        dec = 0
        frac = 0
        frac_divider = 1
        sign = 1

        # read first byte
        case (ch = yield ScanfReq::Getc)
        when '+'.ord
        when '-'.ord
          sign = -1
        else
          if isdigit(ch.to_int) == 1
            dec = (ch - '0'.ord).to_i32
          else
            return read_bytes
          end
        end
        read_bytes += 1

        # read some digits
        while (ch = yield ScanfReq::Getc)
          if isdigit(ch.to_int) == 1
            digit = ch - '0'.ord
            dec = dec * 10 + digit
          elsif ch == '.'.ord
            read_bytes += 1
            # fractional part
            while (ch = yield ScanfReq::Getc)
              if isdigit(ch.to_int) == 1
                digit = ch - '0'.ord
                frac = frac * 10 + digit
                frac_divider *= 10
              else
                yield ScanfReq::Ungetc
                break
              end
            end
            break
          else
            yield ScanfReq::Ungetc
            break
          end
          read_bytes += 1
        end
        
        if length_field == LengthField::None
          fptr = args.next(Pointer(Float32))
          fptr.value = sign.to_f32 * (dec.to_f32 + frac.to_f32 / frac_divider.to_f32)
        else
          fptr = args.next(Pointer(Float64))
          fptr.value = sign.to_f64 * (dec.to_f64 + frac.to_f64 / frac_divider.to_f64)
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
        while '0'.ord <= format.value <= '9'.ord
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

    while format.value != 0
      break if format.value == '%'.ord
      return read_bytes if format.value != yield ScanfReq::Getc
      read_bytes += 1
      format += 1
    end
  end
  read_bytes
end

private def internal_sscanf(str : UInt8*, format : UInt8*, args : VaList)
  internal_gscanf(format, args) do |req|
    case req
    when ScanfReq::Getc
      ch = str.value
      if ch == 0
        0
      else
        str += 1
        ch
      end
    when ScanfReq::Ungetc
      str -= 1
      0
    else
      0
    end
  end
end

fun sscanf(str : UInt8*, format : UInt8*, ...) : LibC::Int
  VaList.open do |args|
    internal_sscanf(str, format, args)
  end
end
