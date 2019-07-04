fun memset(dst : UInt8*, c : UInt32, n : UInt32) : Void*
    i = 0
    while i < n
        dst[i] = c.to_u8
        i += 1
    end
    Pointer(Void).new dst.address
end