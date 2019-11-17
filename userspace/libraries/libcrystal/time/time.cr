lib LibC
  alias TimeT = ULongLong

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

  fun _sys_time : TimeT
  fun localtime(time_t : LibC::TimeT*) : LibC::Tm*
  fun strftime(s : LibC::UString, max : LibC::SizeT,
               format : LibC::UString, tm : LibC::Tm*) : LibC::SizeT
end

struct Time
  def initialize(@year : Int32,
                 @month : Int32,
                 @day : Int32,
                 @hour : Int32 = 0,
                 @minute : Int32 = 0,
                 @second : Int32 = 0)
  end

  def self.unix : UInt64
    LibC._sys_time
  end

  def self.local : Time
    stamp = Time.unix
    tm = LibC.localtime(pointerof(stamp)).value
    Time.new tm.tm_year,
      tm.tm_mon,
      tm.tm_mday,
      tm.tm_hour,
      tm.tm_min,
      tm.tm_sec
  end

  private def to_libc_tm
    tm = LibC::Tm.new
    tm.tm_year = @year
    tm.tm_mon = @month
    tm.tm_mday = @day
    tm.tm_hour = @hour
    tm.tm_min = @minute
    tm.tm_sec = @second
    tm
  end

  def to_s(format : String)
    capacity = 128
    String.new(capacity) do |buffer|
      timeinfo = to_libc_tm
      size = LibC.strftime(buffer, capacity,
        format.to_unsafe,
        pointerof(timeinfo))
      {size, size}
    end
  end
end
