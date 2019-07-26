fun test_alloc1
  x = KERNEL_ARENA.malloc(16)
  Serial.puts "ptr: ", Pointer(Void).new(x.to_u64), "\n"
  KERNEL_ARENA.free x.to_u32
  x = KERNEL_ARENA.malloc(16)
  Serial.puts "ptr: ", Pointer(Void).new(x.to_u64), "\n"
  KERNEL_ARENA.free x.to_u32
end

fun test_alloc2
  Serial.puts "ptr: ", Pointer(Void).new(KERNEL_ARENA.malloc(16).to_u64), "\n"
  Serial.puts "ptr: ", Pointer(Void).new(KERNEL_ARENA.malloc(32).to_u64), "\n"
  Serial.puts "ptr: ", Pointer(Void).new(KERNEL_ARENA.malloc(256).to_u64), "\n"
  Serial.puts "ptr: ", Pointer(Void).new(KERNEL_ARENA.malloc(128).to_u64), "\n"
end
