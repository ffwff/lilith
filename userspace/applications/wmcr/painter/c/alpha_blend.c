#include <stdlib.h>
#include <x86intrin.h>

static inline __m128i clip_u8(__m128i dst) {
  // calculate values > 0xFF
  const __m128i zeroes = _mm_setr_epi32(0, 0, 0, 0);
  const __m128i mask = _mm_setr_epi16(0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF);
  __m128i overflow = _mm_srli_epi16(dst, 8);     // dst = dst >> 8
  overflow = _mm_cmpgt_epi16(overflow, zeroes);  // 0xFFFF if overflow[i] > 0, else 0
  dst = _mm_or_si128(dst, overflow);             // dst | overflow
  dst = _mm_and_si128(dst, mask);                // chop higher bits
  return dst;
}

static __m128i alpha_blend_array(__m128i dst, __m128i src) {
  const __m128i rbmask = _mm_setr_epi32(0x00FF00FF, 0x00FF00FF, 0x00FF00FF, 0x00FF00FF);
  const __m128i gmask = _mm_setr_epi32(0x0000FF00, 0x0000FF00, 0x0000FF00, 0x0000FF00);
  const __m128i amask = _mm_setr_epi32(0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000);

  const __m128i asub = _mm_setr_epi16(0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF);
  const __m128i rbadd = _mm_setr_epi16(0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1, 0x1);
  const __m128i gadd = _mm_setr_epi16(0x1, 0x0, 0x1, 0x0, 0x1, 0x0, 0x1, 0x0);

  // alpha(u16) = { A, A, B, B, C, C, D, D }
  __m128i a = _mm_and_si128(src, amask);
  a = _mm_srli_si128(a, 3);
  // swizzle alpha by RB pairs
#if defined(__SSSE3__)
  a = _mm_shuffle_epi8(a, _mm_set_epi8(1, 8, 1, 8, 1, 12, 1, 12, 1, 4, 1, 4, 1, 0, 1, 0));
#else
  a = _mm_shufflehi_epi16(a, _MM_SHUFFLE(0, 0, 2, 2));
  a = _mm_shufflelo_epi16(a, _MM_SHUFFLE(2, 2, 0, 0));
#endif
  a = _mm_subs_epu8(asub, a);  // a = 0xff - a

  // RB * (0xff - alpha) / 0xff
  __m128i rb = _mm_and_si128(dst, rbmask);
  rb = _mm_mullo_epi16(rb, a);
  rb = _mm_srli_epi16(rb, 8);    // RB = RB >> 8
  rb = _mm_adds_epi16(rb, rbadd);  // RB = RB + 1
  // add:
  rb = _mm_adds_epi16(rb, _mm_and_si128(src, rbmask));  // RB += RB(src)
  rb = clip_u8(rb);

  // G * (1 - alpha)
  __m128i g = _mm_and_si128(dst, gmask);
  g = _mm_srli_epi16(g, 8);  // (trim blue portion)
  g = _mm_mullo_epi16(g, a);
  g = _mm_srli_epi16(g, 8);   // G = G >> 8
  g = _mm_adds_epi16(g, gadd);  // G = G + 1
  // add:
  __m128i src_g = _mm_srli_epi16(_mm_and_si128(src, gmask), 8);
  g = _mm_adds_epi16(g, src_g);
  g = clip_u8(g);
  // shift
  g = _mm_slli_epi16(g, 8);

  return _mm_or_si128(rb, g);
}

void alpha_blend(unsigned char *dst, const unsigned char *src, size_t size) {
  __m128i *dst128 = (__m128i *)dst;
  __m128i *src128 = (__m128i *)src;
  for (size_t i = 0; i < size; i++) {
    _mm_storeu_si128(dst128 + i, alpha_blend_array(_mm_loadu_si128(dst128 + i), _mm_loadu_si128(src128 + i)));
  }
}
