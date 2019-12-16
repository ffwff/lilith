module Painter
  extend self

  class Bitmap
    @to_unsafe = Pointer(UInt32).null
    getter width, height, to_unsafe

    def initialize(@width : Int32, @height : Int32)
      @to_unsafe = LibC.calloc(1, malloc_size).as(UInt32*)
    end

    def initialize(@width : Int32, @height : Int32, @to_unsafe : UInt32*)
    end

    def resize(@width : Int32, @height : Int32)
      @to_unsafe = LibC.realloc(@to_unsafe, malloc_size).as(UInt32*)
    end

    def free
      LibC.free @to_unsafe
      @to_unsafe = Pointer(UInt32).null
    end
    
    private def malloc_size
      @width.to_u64 * @height.to_u64 * sizeof(UInt32)
    end
  end

end
