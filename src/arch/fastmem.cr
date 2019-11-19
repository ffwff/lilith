def zero_page(mem : UInt8*, npages : USize = 1)
  return if npages == 0
  count = npages * 0x200
  r0 = r1 = r2 = 0
  asm("cld\nrep stosq"
          : "={ax}"(r0), "={Di}"(r1), "={cx}"(r2)
          : "{ax}"(0), "{Di}"(mem), "{cx}"(count)
          : "volatile", "memory")
end
