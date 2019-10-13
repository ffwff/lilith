require "./cmos.cr"

module RTC
  extend self

  UNIX_YEAR = 1970

  SECS_MINUTE = 60
  SECS_HOUR   = SECS_MINUTE * 60
  SECS_DAY    = SECS_HOUR * 24

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

  private def secs_of_month(months, year) : UInt64
    days = 0u64
    while months > 0
      case months
      when 11; days += 30
      when 10; days += 31
      when  9; days += 30
      when  8; days += 31
      when  6; days += 30
      when  5; days += 31
      when  4; days += 30
      when  3; days += 31
      when 2
        days += 28
        if (year % 4 == 0) && ((year % 100 != 0) || (year % 400 == 0))
          days += 1
        end
      when 1; days += 31
      end
      months -= 1
    end
    days * SECS_DAY
  end

  def unix
    i = 0
    while CMOS.update_in_process? && i < 10_000
      i += 1
    end
    if i == 10_000
      Serial.puts "rtc: timeout"
    end
    second = CMOS.get_register(0x0).to_u64
    minute = CMOS.get_register(0x2).to_u64
    hour = CMOS.get_register(0x4).to_u64
    day = CMOS.get_register(0x7).to_u64
    month = CMOS.get_register(0x8).to_u64
    year = CMOS.get_register(0x9).to_u64

    reg_b = CMOS.get_register(0x0B)

    if (reg_b & 0x04) == 0
      # convert BCD to binary values
      second = (second & 0x0F) + ((second / 16) * 10)
      minute = (minute & 0x0F) + ((minute / 16) * 10)
      hour = ((hour & 0x0F) + (((hour & 0x70) / 16) * 10)) | (hour & 0x80)
      day = (day & 0x0F) + ((day / 16) * 10)
      month = (month & 0x0F) + ((month / 16) * 10)
      year = (year & 0x0F) + ((year / 16) * 10)
    end

    if (reg_b & 0x02) == 0 && (hour & 0x80) != 0
      # convert 12 hr clock to 24 hr clock
      hour = ((hour & 0x7F) + 12) % 24
    end

    # add century
    # TODO: read from century register
    year += 2000

    stamp = secs_of_years(year - 1) +
            secs_of_month(month, year) +
            day * SECS_DAY +
            hour * SECS_HOUR +
            minute * SECS_MINUTE +
            second

    stamp
  end
end
