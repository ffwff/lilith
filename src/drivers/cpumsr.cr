module X86
  extend self

  @[AlwaysInline]
  def rdmsr(msr : UInt32) : UInt64
    lo = 0u32
    hi = 0u32
    asm("rdmsr" : "={eax}"(lo), "={edx}"(hi) : "{ecx}"(msr) :: "volatile")
    hi.to_u64.unsafe_shr(32) | lo.to_u64
  end

  @[AlwaysInline]
  def wrmsr(msr : UInt32, val : UInt64)
    lo = (val & 0xFFFF_FFFF).to_u32
    hi = (val.unsafe_shr(8) & 0xFFFF_FFFF).to_u32
    asm("wrmsr" :: "{eax}"(lo), "{edx}"(hi), "{ecx}"(msr) :: "volatile")
  end
end
