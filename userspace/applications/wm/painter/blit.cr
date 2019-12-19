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
      fb_offset = ((sy + y) * dw + sx)
      blit_u32(db + fb_offset, color.to_u32, sw_clamp.to_usize)
    end
  end
  
  def blit_rect(dest : Bitmap, sx : Int, sy : Int, color : Int)
    blit_rect dest.to_unsafe, dest.width, dest.height,
              dest.width, dest.height, sx, sy, color
  end

  def blit_rect(dest : Bitmap, sw : Int, sh : Int, sx : Int, sy : Int, color : Int)
    blit_rect dest.to_unsafe, dest.width, dest.height,
              sw, sh, sx, sy, color
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

  def blit_img(dest : Bitmap, src : Bitmap, sx : Int, sy : Int, alpha? = false)
    blit_img  dest.to_unsafe, dest.width, dest.height,
              src.to_unsafe, src.width, src.height,
              sx, sy, alpha?
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

  def blit_img(dest : Bitmap, src : Bitmap, dx : Int, dy : Int, sx : Int, sy : Int, alpha? = false)
    blit_img  dest.to_unsafe, dest.width, dest.height,
              src.to_unsafe, src.width, src.height,
              dx, dy, sx, sy, alpha?
  end

  def blit_img_cropped(db : UInt32*, dw : Int, dh : Int,
                       sb : UInt32*, sw : Int, sh : Int,
                       cw : Int, ch : Int,
                       cx : Int, cy : Int,
                       dx : Int, dy : Int,
                       sx : Int, sy : Int,
                       alpha? = false)
    if dy + dh > dh
      if dh < dy # dh - dy < 0
        return
      else
        sh_clamp = dh - dy
      end
    else
      sh_clamp = dh
    end
    sh_clamp = Math.min(Math.min(sh_clamp, sh - cy), ch)

    if dx + dw > dw
      if dw < dx # dw - dx < 0
        return
      else
        sw_clamp = dw - dx
      end
    else
      sw_clamp = dw
    end
    sw_clamp = Math.min(Math.min(sw_clamp, sw - cx), cw)
    # sw_clamp = Math.min(sw_clamp, cw)

    # STDERR.print sx, ' ', sy, ' ', cx, ' ', cy, ' ', sw_clamp, ' ', sh_clamp, ' ', sw, ' ', sh, '\n'

    sh_clamp.times do |y|
      fb_offset = ((sy + y) * dw + sx) * 4
      src_offset = (cy + y) * sw * 4 + cx * 4
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

  def blit_img_cropped(dest : Bitmap, src : Bitmap,
                       cw : Int, ch : Int,
                       cx : Int, cy : Int,
                       dx : Int, dy : Int,
                       sx : Int, sy : Int, alpha? = false)
    blit_img_cropped dest.to_unsafe, dest.width, dest.height,
                     src.to_unsafe, src.width, src.height,
                     cw, ch, cx, cy, dx, dy, sx, sy, alpha?
  end
end
