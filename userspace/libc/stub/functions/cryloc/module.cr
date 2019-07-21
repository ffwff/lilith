# TODO: Write documentation for `Cryloc`
module Cryloc
  VERSION = "0.1.0"

  def self.allocate(size : SizeT) : Void*
    SimpleAllocator.allocate(size)
  end

  def self.release(ptr : Void*)
    SimpleAllocator.release(ptr)
  end

  def self.re_allocate(ptr : Void*, size : SizeT) : Void*
    SimpleAllocator.re_allocate(ptr, size)
  end

  def self.allocate_aligned(alignment : SizeT, size : SizeT) : Void*
    SimpleAllocator.allocate_aligned(alignment, size)
  end
end
