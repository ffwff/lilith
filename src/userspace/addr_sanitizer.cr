module UserAddressSanitiser
  extend self

  def checked_pointer(size, addr) : Void*?
    addr = addr.to_u64
    size = size.to_u64
    i = addr
    while i < (addr + size)
      return nil unless Paging.check_user_addr(i)
      i += 0x1000u64
    end
    Pointer(Void).new(addr)
  end

  def checked_slice(addr, len) : Slice(UInt8)?
    addr = addr.to_u64
    len = len.to_u64
    i = addr
    while i < (addr + len)
      return nil unless Paging.check_user_addr(i)
      i += 0x1000u64
    end
    Slice(UInt8).new(Pointer(UInt8).new(addr), len.to_i32)
  end

end

macro checked_pointer(t, addr)
  begin
    if (ptr = UserAddressSanitiser.checked_pointer(sizeof({{ t }}), {{ addr }}))
      ptr.as({{ t }}*)
    else
      nil  
    end
  end
end

macro checked_slice(addr, len)
  UserAddressSanitiser.checked_slice({{ addr }}, {{ len }})
end