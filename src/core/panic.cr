def panic(*args)
  # TODO: print call stack
  Serial.print *args
  Pointer(Int32).null.value = 0
  while true
  end
end

def raise(*args)
end

fun breakpoint
  asm("nop")
end
