# HACK: functions which prevent LLVM from optimizing away
# architecturally-significant memory (i.e. page directories)
# with the --release, -O1 flags
#
# This should only be used as a last resort.
lib LibHax
  fun no_opt(data : UInt64)
end

macro no_opt(x)
  LibHax.no_opt({{ x }})
end
