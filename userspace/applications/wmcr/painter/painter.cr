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

  def blit_u32(dst : UInt32*, c : UInt32, n : LibC::SizeT)
    asm(
      "cld\nrep stosl"
        :: "{eax}"(c), "{Di}"(dst), "{ecx}"(n)
        : "volatile", "memory", "Di", "eax", "ecx"
    )
  end

  def blit_rect(db, dw, dh, sw, sh, sx, sy, color)
    if sx == 0 && sy == 0 && dw == sw && dh == sh
      return blit_u32(db, color.to_u32, sw.to_usize * sh.to_usize)
    end
    sh.times do |y|
      fb_offset = ((sy + y) * dw + sx)
      blit_u32(db + fb_offset, color.to_u32, sw.to_usize)
    end
  end

  def blit_img(db, dw, dh,
               sb, sw, sh, sx, sy)
    if sx == 0 && sy == 0 && sw == dw && sh == dh
      LibC.memcpy db, sb, dw.to_u32 * dh.to_u32 * 4
      return 
    end
    if sy + sh > dh
      if dh < sy # dh - sy < 0
        sh = 0
      else
        sh = dh - sy
      end
    end
    if sx + sw > dw
      if dw < sx # dw - sx < 0
        sw = 0
      else
        sw = dw - sx
      end
    end
    sh.times do |y|
      fb_offset = ((sy + y) * dw + sx) * 4
      src_offset = y * sw * 4
      copy_size = sw * 4
      LibC.memcpy(db.as(UInt8*) + fb_offset,
                  sb.as(UInt8*) + src_offset,
                  copy_size)
    end
  end

  struct Image
    getter width, height, bytes
    def initialize(@width : Int32, @height : Int32, @bytes : Bytes)
    end
  end

  def load_png(filename) : Image?
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

    bytes = Bytes.new(width * height * 4)
    height.times do |y|
      LibPNG.png_read_row png_ptr, bytes.to_unsafe + (y * width * 4), Pointer(UInt8).null
    end

    LibPNG.png_destroy_read_struct pointerof(png_ptr), pointerof(info_ptr), Pointer(Void*).null

    Image.new width.to_i32, height.to_i32, bytes
  end
end
