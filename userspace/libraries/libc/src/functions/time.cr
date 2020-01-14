lib LibC
  alias TimeT = ULongLong
  alias SusecondsT = LongLong
  alias UsecondsT = ULongLong
  alias ClockT = ULongLong

  struct Timeval
    tv_sec : TimeT
    tv_usec : SusecondsT
  end

  struct Tm
    tm_sec : LibC::Int
    tm_min : LibC::Int
    tm_hour : LibC::Int
    tm_mday : LibC::Int
    tm_mon : LibC::Int
    tm_year : LibC::Int
    tm_wday : LibC::Int
    tm_yday : LibC::Int
    tm_isdst : LibC::Int
  end
end

module Time
  extend self

  @@tm = uninitialized LibC::Tm

  def tm_p
    pointerof(@@tm)
  end
end

private UNIX_YEAR   =  1970
private SECS_MINUTE = 60u64
private SECS_HOUR   = SECS_MINUTE * 60
private SECS_DAY    = SECS_HOUR * 24

private def leap_year?(year)
  (year % 4 == 0) && ((year % 100 != 0) || (year % 400 == 0))
end

private def days_in_month_of_year(month, year)
  case month
  when 12; 31
  when 11; 30
  when 10; 31
  when  9; 30
  when  8; 31
  when  6; 30
  when  5; 31
  when  4; 30
  when  3; 31
  when  2; leap_year?(year) ? 29 : 28
  when  1; 31
  else     0
  end
end

private def secs_of_years(years) : UInt64
  days = 0u64
  while years >= UNIX_YEAR
    days += 365
    if years % 4 == 0
      if years % 100 == 0
        if years % 400 == 0
          days += 1
        end
      else
        days += 1
      end
    end
    years -= 1
  end
  days * SECS_DAY
end

fun gettimeofday(tv : LibC::Timeval*, tz : Void*) : LibC::Int
  seconds = _sys_time
  tv.value.tv_sec = seconds
  tv.value.tv_usec = 0
  0
end

fun gmtime(tm : LibC::TimeT*) : LibC::Tm*
  # TODO
  localtime(tm)
end

fun localtime(time_t : LibC::TimeT*) : LibC::Tm*
  seconds = time_t.value

  years = UNIX_YEAR
  while seconds > 0
    seconds_in_year = (leap_year?(years) ? 366 : 365) * SECS_DAY
    if seconds_in_year <= seconds
      seconds -= seconds_in_year
      years += 1
    else
      break
    end
  end

  months = 1
  while seconds > 0 && months < 12
    days = days_in_month_of_year(months, years)
    seconds_in_month = (days * SECS_DAY).to_u64
    if seconds_in_month <= seconds
      seconds -= seconds_in_month
      months += 1
    else
      break
    end
  end

  days = 0
  while seconds > 0
    if SECS_DAY <= seconds
      seconds -= SECS_DAY
      days += 1
    else
      break
    end
  end

  while days >= days_in_month_of_year(months, years) && months < 12
    days -= days_in_month_of_year(months, years)
    months += 1
  end

  hours = 0
  while seconds > 0
    if SECS_HOUR <= seconds
      seconds -= SECS_HOUR
      hours += 1
    else
      break
    end
  end

  minutes = 0
  while seconds > 0
    if SECS_MINUTE <= seconds
      seconds -= SECS_MINUTE
      minutes += 1
    else
      break
    end
  end

  tm = uninitialized LibC::Tm

  tm.tm_year = years
  tm.tm_mon = months - 1
  tm.tm_mday = days
  tm.tm_hour = hours
  tm.tm_min = minutes
  tm.tm_sec = seconds

  Time.tm_p.value = tm
  Time.tm_p
end

fun time(tloc : LibC::TimeT*) : LibC::TimeT
  retval = _sys_time
  unless tloc.null?
    tloc.value = retval
  end
  retval
end

fun clock : LibC::ClockT
  # TODO
  0.to_ulonglong
end

fun difftime(t1 : LibC::ULong, t0 : LibC::ULong) : Float64
  # TODO
  0.0f64
end

fun mktime(timep : Void*) : LibC::TimeT
  # TODO
  0.to_ulonglong
end

private macro nformat(n, pad = 0)
  str, size = printf_int({{ n }})
  if {{ pad }} > 0 && size < {{ pad }}
    padsize = Math.min({{ pad }} - size, max)
    padsize.times do
      s.value = '0'.ord.to_u8
      s += 1
    end
    max -= padsize
    written += padsize
  end
  size = Math.min(size, max)
  strncpy(s, str.to_unsafe, size.to_usize)
  s += size
  max -= size
  written += size
  return written if max == 0
end

fun strftime(s : UInt8*, max : LibC::SizeT,
             format : UInt8*, tm : LibC::Tm*) : LibC::SizeT
  written : LibC::SizeT = 0
  until format.value == 0
    if format.value == '%'.ord
      format += 1
      case format.value
      when 'Y'.ord
        format += 1
        nformat(tm.value.tm_year)
      when 'm'.ord
        format += 1
        nformat(tm.value.tm_mon, 2)
      when 'd'.ord
        format += 1
        nformat(tm.value.tm_mday, 2)
      when 'H'.ord
        format += 1
        nformat(tm.value.tm_hour, 2)
      when 'M'.ord
        format += 1
        nformat(tm.value.tm_min, 2)
      when 'S'.ord
        format += 1
        nformat(tm.value.tm_sec, 2)
      when '%'.ord
        format += 1
      else
        return written
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
      write_amount = Math.min(amount, max)
      strncpy(s, format_start, write_amount.to_usize)
      s += write_amount
      max -= write_amount
      written += write_amount
      return written if max == 0
    end
  end
  written
end
