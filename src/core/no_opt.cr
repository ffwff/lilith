# HACK: functions which prevent LLVM from optimizing away
# volatile memory (i.e. page directories/gc data)
# with the --release, -O1 flags
#
# This should only be used as a last resort.

macro no_opt(x)
  asm("nop" :: "{di}"({{ x }}) : "volatile", "memory")
end
