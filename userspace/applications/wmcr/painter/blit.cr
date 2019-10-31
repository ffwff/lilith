module Painter
  extend self

  def blit_u32(dst : UInt32*, c : UInt32, n : LibC::SizeT)
    asm(
      "cld\nrep stosl"
        :: "{eax}"(c), "{Di}"(dst), "{ecx}"(n)
        : "volatile", "memory", "Di", "eax", "ecx"
    )
  end

  def blit_rect(db : UInt32*,
                dw : Int, dh : Int,
                sw : Int, sh : Int,
                sx : Int, sy : Int, color : Int)
    if sx == 0 && sy == 0 && dw == sw && dh == sh
      return blit_u32(db, color.to_u32, sw.to_usize * sh.to_usize)
    end
    sh.times do |y|
      fb_offset = ((sy.to_usize + y.to_usize) * dw.to_usize + sx.to_usize)
      blit_u32(db + fb_offset, color.to_u32, sw.to_usize)
    end
  end

  def blit_img(db : UInt32*, dw : Int, dh : Int,
               sb : UInt32*, sw : Int, sh : Int,
               sx : Int, sy : Int)
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
end
