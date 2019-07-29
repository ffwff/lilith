def checked_pointer(addr : UInt32) : Void*?
  if addr < USERSPACE_START
    nil
  else
    Pointer(Void).new(addr.to_u64)
  end
end

def checked_slice(addr : UInt32, len : Int32) : Slice(UInt8)?
  end_addr = addr + len
  if addr < USERSPACE_START || end_addr < USERSPACE_START
    nil
  else
    Slice(UInt8).new(Pointer(UInt8).new(addr.to_u64), len.to_i32)
  end
end
