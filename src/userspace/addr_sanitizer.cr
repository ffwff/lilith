def checked_pointer32(addr) : Void*?
  Pointer(Void).new(addr.to_u64)
end

def checked_slice32(addr : UInt32, len : Int32) : Slice(UInt8)?
  Slice(UInt8).new(Pointer(UInt8).new(addr.to_u64), len)
end
