lib LibC
  alias TimeT = ULongLong
  alias SusecondsT = ULongLong

  struct Timeval
    tv_sec : TimeT
    tv_usec : SusecondsT
  end
  
  struct Tm
    tm_sec   : LibC::Int
    tm_min   : LibC::Int
    tm_hour  : LibC::Int
    tm_mday  : LibC::Int
    tm_mon   : LibC::Int
    tm_year  : LibC::Int
    tm_wday  : LibC::Int
    tm_yday  : LibC::Int
    tm_isdst : LibC::Int
  end
  
  $__libc_timeval : Timeval
  $__libc_tm : Tm
end

private UNIX_YEAR = 1970
private SECS_MINUTE = 60
private SECS_HOUR   = SECS_MINUTE * 60
private SECS_DAY    = SECS_HOUR   * 24

private def leap_year?(year)
  (year % 4 == 0) && ((year % 100 != 0) || (year % 400 == 0))
end

private def days_in_month_of_year(month, year)
  case month
  when 11; 30
  when 10; 31
  when 9;  30
  when 8;  31
  when 6;  30
  when 5;  31
  when 4;  30
  when 3;  31
  when 2;  leap_year?(year) ? 29 : 28
  when 1;  31
  else; 0
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
  
  years = 1970
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
  while seconds > 0
    days = days_in_month_of_year(months, years)
    seconds_in_month = days * SECS_DAY
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

  while days >= days_in_month_of_year(months, years)
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
  
  tm.tm_year  = years
  tm.tm_mon   = months - 1
  tm.tm_mday  = days
  tm.tm_hour  = hours
  tm.tm_min   = minutes
  tm.tm_sec   = seconds
  
  pointerof(LibC.__libc_tm).value = tm
  
  pointerof(LibC.__libc_tm)
end

fun clock : LibC::ULong
  # TODO
  0u32
end

fun difftime(t1 : LibC::ULong, t0 : LibC::ULong) : Float64
  # TODO
  0.0f64
end

fun mktime(timep : Void*) : LibC::ULong
  # TODO
  0u32
end
