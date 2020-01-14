module X86
  extend self

  @@usecs_per_tsc = 0.0f32

  # Executes the `rdtscp` instruction and returns the timestamp in EDX:EAX
  def rdtscp
    tsc = 0u64
    asm("rdtscp
         shl $$32, %rdx
         or %rdx, %rax"
            : "={rax}"(tsc)
            :: "{rcx}", "{rdx}")
    tsc
  end

  # Calculates the number of microseconds a CPU counter returned by `rdtscp` lasts
  def calibrate_tsc
    ts = rdtscp
    old_usecs = Time.usecs_since_boot
    while (new_usecs = Time.usecs_since_boot) == old_usecs
      asm("hlt")
    end
    newts = rdtscp
    @@usecs_per_tsc = (Time.usecs_since_boot - old_usecs).to_f32 / (newts - ts).to_f32
    Serial.print "us: ", (1.0f32/@@usecs_per_tsc).to_i32, '\n'
  end
end
