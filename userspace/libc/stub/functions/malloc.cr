require "./cryloc/**"

fun calloc(nmeb : UInt32, size : UInt32) : Void*
  # puts("CALLOC")
  res = malloc(nmeb * size)
  if res.address != 0
    cryloc_memset(res.as(UInt8*), 0, nmeb * size)
  end
  res
end

fun malloc(size : UInt32) : Void*
  Cryloc.allocate(size)
end

fun free(ptr : Void*)
  Cryloc.release(ptr)
end

fun realloc(ptr : Void*, size : UInt32) : Void*
  Cryloc.re_allocate(ptr, size)
end

fun memalign(alignment : UInt32, size : UInt32) : Void*
  Cryloc.allocate_aligned(alignment, size)
end
