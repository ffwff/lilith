lib LibC
  fun fopen(path : LibC::UString, mode : LibC::UString) : Void*
end

PNG_VER_STRING = "1.6.37"
PNG_COLOR_MASK_PALETTE    = 1
PNG_COLOR_MASK_COLOR      = 2
PNG_COLOR_MASK_ALPHA      = 4
PNG_COLOR_TYPE_GRAY       = 0
PNG_COLOR_TYPE_RGB        = PNG_COLOR_MASK_COLOR
PNG_COLOR_TYPE_GRAY_ALPHA = PNG_COLOR_MASK_ALPHA
PNG_COLOR_TYPE_PALETTE   = (PNG_COLOR_MASK_COLOR | PNG_COLOR_MASK_PALETTE)
PNG_INFO_tRNS = 0x0010u8
PNG_FILLER_AFTER = 1
lib LibPNG
  fun png_create_read_struct(str : LibC::UString, error_ptr : Void*,
                             error_fn : Void*, warn_fn : Void*) : Void*
  fun png_create_info_struct(png_ptr : Void*) : Void*
  fun png_init_io(png_ptr : Void*, fp : Void*)
  fun png_read_info(png_ptr : Void*, info_ptr : Void*)
  fun png_set_strip_16(png_ptr : Void*)
  fun png_set_palette_to_rgb(png_ptr : Void*)
  fun png_set_expand_gray_1_2_4_to_8(png_ptr : Void*)
  fun png_get_valid(png_ptr : Void*, info_ptr : Void*, flag : UInt32) : UInt32
  fun png_set_tRNS_to_alpha(png_ptr : Void*)
  fun png_set_filler(png_ptr : Void*, filler : UInt32, flags : LibC::Int)
  fun png_set_gray_to_rgb(png_ptr : Void*)
  fun png_set_bgr(png_ptr : Void*)
  fun png_read_update_info(png_ptr : Void*, info_ptr : Void*)
  fun png_read_row(png_ptr : Void*, row : UInt8*, display_row : UInt8*)
  fun png_destroy_read_struct(png_ptr_ptr : Void**, info_ptr_ptr : Void**, end_info_ptr_ptr : Void**)
  fun png_get_image_width(png_ptr : Void*, info_ptr : Void*) : UInt32
  fun png_get_image_height(png_ptr : Void*, info_ptr : Void*) : UInt32
  fun png_get_color_type(png_ptr : Void*, info_ptr : Void*) : UInt8
  fun png_get_bit_depth(png_ptr : Void*, info_ptr : Void*) : UInt8
end

module Painter
  extend self

  class Image
    getter width, height, bytes
    def initialize(@width : Int32, @height : Int32, @bytes : Bytes)
    end
  end

  private def internal_load_png(filename, &block)
    if (fp = LibC.fopen(filename, "r")).null?
      return nil
    end

    png_ptr = LibPNG.png_create_read_struct(PNG_VER_STRING, Pointer(Void).null,
                                            Pointer(Void).null, Pointer(Void).null)
    info_ptr = LibPNG.png_create_info_struct(png_ptr)
    LibPNG.png_init_io(png_ptr, fp)
    LibPNG.png_read_info(png_ptr, info_ptr)

    width = LibPNG.png_get_image_width png_ptr, info_ptr
    height = LibPNG.png_get_image_height png_ptr, info_ptr
    color_type = LibPNG.png_get_color_type png_ptr, info_ptr
    bit_depth = LibPNG.png_get_bit_depth png_ptr, info_ptr

    LibPNG.png_set_strip_16(png_ptr) if bit_depth == 16
    LibPNG.png_set_palette_to_rgb(png_ptr) if color_type == PNG_COLOR_TYPE_PALETTE

    if color_type == PNG_COLOR_TYPE_GRAY && bit_depth < 8
      LibPNG.png_set_expand_gray_1_2_4_to_8 png_ptr
    end

    if LibPNG.png_get_valid(png_ptr, info_ptr, PNG_INFO_tRNS)
      LibPNG.png_set_tRNS_to_alpha(png_ptr)
    end

    if color_type == PNG_COLOR_TYPE_RGB ||
       color_type == PNG_COLOR_TYPE_GRAY ||
       color_type == PNG_COLOR_TYPE_PALETTE
      LibPNG.png_set_filler(png_ptr, 0x0, PNG_FILLER_AFTER)
    end

    if color_type == PNG_COLOR_TYPE_GRAY ||
       color_type == PNG_COLOR_TYPE_GRAY_ALPHA
      LibPNG.png_set_gray_to_rgb(png_ptr)
    end

    LibPNG.png_set_bgr(png_ptr)

    LibPNG.png_read_update_info(png_ptr, info_ptr)

    yield Tuple.new(width, height, png_ptr)

    LibPNG.png_destroy_read_struct pointerof(png_ptr), pointerof(info_ptr), Pointer(Void*).null
  end

  def load_png(filename : String, bytes : Bytes)
    internal_load_png(filename) do |width, height, png_ptr|
      if bytes.size == (width * height * 4)
        height.times do |y|
          LibPNG.png_read_row png_ptr, bytes.to_unsafe + (y * width * 4), Pointer(UInt8).null
        end
      end
    end
  end

  def load_png(filename : String) : Image?
    img = nil
    internal_load_png(filename) do |width, height, png_ptr|
      bytes = Bytes.new(width * height * 4)
      height.times do |y|
        LibPNG.png_read_row png_ptr, bytes.to_unsafe + (y * width * 4), Pointer(UInt8).null
      end
      img = Image.new width.to_i32, height.to_i32, bytes
    end
    img
  end

end
