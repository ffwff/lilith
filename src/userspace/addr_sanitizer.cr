def checked_pointer32(addr) : Void*?
  addr = addr.to_u64
  if addr < USERSPACE_START
    nil
  else
    Pointer(Void).new(addr)
  end
end

def checked_slice32(addr : UInt32, len : Int32) : Slice(UInt8)?
  end_addr = addr + len
  if addr < USERSPACE_START || end_addr < USERSPACE_START
    nil
  else
    Slice(UInt8).new(Pointer(UInt8).new(addr.to_u64), len)
  end
end
