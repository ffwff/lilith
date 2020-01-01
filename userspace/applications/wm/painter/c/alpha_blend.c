#include <stdint.h>
#include <stdlib.h>

void alpha_blend(unsigned char * restrict dst, const unsigned char * restrict src, size_t size) {
  unsigned char *rdd = dst;
  const unsigned char *rds = src;
  for (size_t i = 0; i < size; i += 4) {
      unsigned char db = rdd[i + 0], dg = rdd[i + 1], dr = rdd[i + 2];
      const unsigned char sb = rds[i + 0], sg = rds[i + 1], sr = rds[i + 2], sa = rds[i + 3], saf = 0xff - sa;
      rdd[i + 0] = (((uint16_t)sb * sa) >> 8) + (((uint16_t)db * saf) >> 8) + 1;
      rdd[i + 1] = (((uint16_t)sg * sa) >> 8) + (((uint16_t)dg * saf) >> 8) + 1;
      rdd[i + 2] = (((uint16_t)sr * sa) >> 8) + (((uint16_t)dr * saf) >> 8) + 1;
  }
}
