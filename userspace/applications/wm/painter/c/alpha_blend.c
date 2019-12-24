#include <stdint.h>
#include <stdlib.h>

void alpha_blend(unsigned char * restrict dst, const unsigned char * restrict src, size_t size) {
  uint32_t *dptr = (uint32_t*)dst;
  const uint32_t *sptr = (const uint32_t*)src;
  for (size_t i = 0; i < (size/4); i++) {
    uint32_t dcolor = dptr[i];
    uint32_t scolor = sptr[i];
    const uint32_t alpha = scolor >> 24, falpha = 0xff - alpha;
    uint32_t srb = (((scolor & 0xff00ff) * alpha) >> 8) & 0xff00ff;
    uint32_t sg = (((scolor & 0x00ff00) * alpha) >> 8) & 0x00ff00;
    uint32_t drb = (((dcolor & 0xff00ff) * falpha) >> 8) & 0xff00ff;
    uint32_t dg = (((dcolor & 0x00ff00) * falpha) >> 8) & 0x00ff00;

    uint32_t nrb = drb + srb;
    if((nrb&0xff000000)!=0) nrb |= 0x00ff0000;
    if((nrb&0x0000ff00)!=0) nrb |= 0x000000ff;

    uint32_t ng = dg + sg;
    if((ng&0x00ff0000)!=0) nrb |= 0x0000ff00;

    dptr[i] = (nrb & 0xFF00FF) | (ng & 0x00FF00);
  }
}
