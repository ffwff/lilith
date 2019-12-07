module Painter
  extend self

  lib Lib
    fun alpha_blend(dst : Void*, src : Void*, size : LibC::SizeT)
  end

  def blit_u32(dst : UInt32*, c : UInt32, n : LibC::SizeT)
    r0 = r1 = r2 = 0
    asm(
      "cld\nrep stosl"
        : "={eax}"(r0), "={Di}"(r1), "={ecx}"(r2)
        : "{eax}"(c), "{Di}"(dst), "{ecx}"(n)
        : "volatile", "memory"
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
               sx : Int, sy : Int,
               alpha? = false)
    if sx == 0 && sy == 0 && sw == dw && sh == dh
      if alpha?
        Lib.alpha_blend db, sb, dw.to_u32 * dh.to_u32 // 4
      else
        LibC.memcpy db, sb, dw.to_u32 * dh.to_u32 * 4
      end
      return 
    end
    if sy + sh > dh
      if dh < sy # dh - sy < 0
        return
      else
        sh_clamp = dh - sy
      end
    else
      sh_clamp = sh
    end
    if sx + sw > dw
      if dw < sx # dw - sx < 0
        return
      else
        sw_clamp = dw - sx
      end
    else
      sw_clamp = sw
    end
    sh_clamp.times do |y|
      fb_offset = ((sy + y) * dw + sx) * 4
      src_offset = y * sw * 4
      if alpha?
        Lib.alpha_blend(db.as(UInt8*) + fb_offset,
                        sb.as(UInt8*) + src_offset,
                        sw_clamp // 4)
      else
        LibC.memcpy(db.as(UInt8*) + fb_offset,
                    sb.as(UInt8*) + src_offset,
                    sw_clamp * 4)
      end
    end
  end

  def blit_img(db : UInt32*, dw : Int, dh : Int,
               sb : UInt32*, sw : Int, sh : Int,
               dx : Int, dy : Int,
               sx : Int, sy : Int,
               alpha? = false)
    if sx == 0 && sy == 0 && sw == dw && sh == dh
      if alpha?
        Lib.alpha_blend db, sb, dw.to_u32 * dh.to_u32 // 4
      else
        LibC.memcpy db, sb, dw.to_u32 * dh.to_u32 * 4
      end
      return 
    end

    sx = Math.max(sx, 0)
    sy = Math.max(sy, 0)

    if dy + dh > dh
      if dh < dy # dh - dy < 0
        return
      else
        sh_clamp = dh - dy
      end
    else
      sh_clamp = dh
    end
    sh_clamp = Math.min(sh_clamp, sh - sy)

    if dx + dw > dw
      if dw < dx # dw - dx < 0
        return
      else
        sw_clamp = dw - dx
      end
    else
      sw_clamp = dw
    end
    sw_clamp = Math.min(sw_clamp, sw - sx)

    sh_clamp.times do |y|
      fb_offset = ((dy + y) * dw + sx) * 4
      src_offset = (sy + y) * sw * 4
      if alpha?
        Lib.alpha_blend(db.as(UInt8*) + fb_offset,
                        sb.as(UInt8*) + src_offset,
                        sw_clamp // 4)
      else
        LibC.memcpy(db.as(UInt8*) + fb_offset,
                    sb.as(UInt8*) + src_offset,
                    sw_clamp * 4)
      end
    end
  end
end
