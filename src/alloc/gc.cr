require "./alloc.cr"

fun __crystal_malloc64(_size : UInt64) : Void*
    size = _size.to_u32
    ptr = Pointer(Void).new(KERNEL_ARENA.malloc(size).to_u64)
    Serial.puts ptr
    ptr
end

fun __crystal_malloc_atomic64(_size : UInt64) : Void*
    size = _size.to_u32
    ptr = Pointer(Void).new(KERNEL_ARENA.malloc(size).to_u64)
    Serial.puts ptr
    ptr
end