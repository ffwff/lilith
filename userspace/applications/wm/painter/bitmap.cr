module Painter
  extend self

  # FIXME: would be better to have an actual Bitmap class
  def create_bitmap(width : Int, height : Int)
    Gc.unsafe_malloc(width.to_u64 * height.to_u64 * sizeof(UInt32), true).as(UInt32*)
  end

  def resize_bitmap(orig : UInt32*, width : Int, height : Int)
    orig.realloc(width.to_u64 * height.to_u64)
  end

end
