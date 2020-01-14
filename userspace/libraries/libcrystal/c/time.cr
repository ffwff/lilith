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
