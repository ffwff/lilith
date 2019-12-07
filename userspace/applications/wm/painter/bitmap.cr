module Painter
  extend self

  # FIXME: would be better to have an actual Bitmap class
  def create_bitmap(width : Int, height : Int) : UInt32*
    size = width.to_u64 * height.to_u64 * sizeof(UInt32)
    ptr = Gc.unsafe_malloc(size, true).as(UInt32*)
    LibC.memset ptr, 0, size
    ptr
  end

  def resize_bitmap(orig : UInt32*, width : Int, height : Int)
    orig.realloc(width.to_u64 * height.to_u64)
  end

end
