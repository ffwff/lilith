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
        return written
      when '%'.ord
        format += 1
        return read_bytes if '%'.ord != yield ScanfReq::Getc
        read_bytes == 1
      when 'c'.ord
        format += 1
        ch = args.next(Pointer(UInt8))
        return read_bytes if '%'.ord != yield ScanfReq::Getc
        read_bytes == 1
        return written if (retval = yield ch.unsafe_chr) == 0
        written += retval
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
          if isdigit(ch)
            num = ch - '0'.ord
          else
            return read_bytes
          end
        end
        read_bytes += 1

        # read some digits
        while (ch = yield ScanfReq::Getc)
          if isdigit(ch)
            digit = ch - '0'.ord
            num = num * 10 + digit
          else
            yield ScanfReq::Ungetc
            break
          end
          read_bytes += 1
        end

        num *= sign
        intptr = args.next(LibC::Int*)
        intptr.value = num
      when 'f'.ord
        format += 1
        # TODO: implement
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

    while format.value != 0
      break if format.value == '%'.ord
      return read_bytes if format.value != yield ScanfReq::Getc
      read_bytes += 1
      format += 1
    end
  end
  read_bytes
end

private def internal_scanf(str : UInt8*, format : UInt8*, args : VaList)
  internal_scanf(format, args) do |req|
    case req
    when ScanfReq::Getc
      ch = str.value
      str += 1
      ch
    when ScanfReq::Ungetc
      str -= 1
      0
    end
  end
end

fun cr_scanf(str : UInt8*, format : UInt8*, ...) : LibC::Int
  VaList.open do |args|
    internal_scanf(str, format, args)
  end
end
