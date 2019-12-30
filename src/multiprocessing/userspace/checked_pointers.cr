def checked_pointer(type : T.class, addr : UInt64) : T*? forall T
  i = addr.to_u64
  end_addr = addr.to_u64 + sizeof(T).to_u64
  while i < end_addr
    return unless Paging.check_user_addr(Pointer(Void).new(i))
    i += 0x1000u64
  end
  Pointer(T).new(addr)
end

def checked_slice(addr : UInt64, len : Int) : Slice(UInt8)?
  i = addr.to_u64
  end_addr = addr.to_u64 + len.to_u64
  while i < end_addr
    return unless Paging.check_user_addr(Pointer(Void).new(i))
    i += 0x1000u64
  end
  Slice(UInt8).new Pointer(UInt8).new(addr), len.to_i32
end

def checked_slice(type : T.class, addr : UInt64, len : Int) : Slice(T)? forall T
  i = addr.to_u64
  end_addr = addr.to_u64 + len.to_u64 * sizeof(T).to_u64
  while i < end_addr
    return unless Paging.check_user_addr(Pointer(Void).new(i))
    i += 0x1000u64
  end
  Slice(T).new Pointer(T).new(addr), (len.to_i32 * sizeof(T))
end
