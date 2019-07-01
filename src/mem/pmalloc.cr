private lib Kernel
    $kernel_end : UInt32
end

struct Internal
    @addr = Kernel.kernel_end
    def addr(); @addr; end
    def addr=(x); @addr = x; end
end

INTERNAL = Internal.new

def pmalloc(sz) : Pointer(Void)
    addr = INTERNAL.addr
    x = INTERNAL.addr + sz
    INTERNAL.addr = x
    Pointer(Void).new addr.to_u64
end

def pmalloc_a(sz) : Pointer(Void)
    if INTERNAL.addr & 0xFFFFF000
        x = INTERNAL.addr & 0xFFFFF000 + 0x1000
        INTERNAL.addr = x
    end
    pmalloc sz
end