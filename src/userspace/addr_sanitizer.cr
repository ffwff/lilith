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
  
  def checked_slice(addr, size, len) : Slice(UInt8)?
    checked_slice(addr, size * len)
  end

end

macro checked_pointer(t, addr)
  if (__ptr = UserAddressSanitiser.checked_pointer(sizeof({{ t }}), {{ addr }}))
    __ptr.as({{ t }}*)
  else
    nil
  end
end

macro checked_slice(addr, len)
  UserAddressSanitiser.checked_slice({{ addr }}, {{ len }})
end

macro checked_slice(t, addr, len)
  if (__ptr = UserAddressSanitiser.checked_slice({{ addr }}, sizeof({{ t }}), {{ len }}))
    Slice({{ t }}).new(__ptr.to_unsafe.as({{ t }}*), {{ len }})
  else
    nil
  end
end
