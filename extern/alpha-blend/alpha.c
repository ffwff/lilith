#include <x86intrin.h>

#ifndef ASSEMBLY
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <time.h>
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

// p /x *(unsigned int*)&x@4
/*
cc -msse2 -g -o /tmp/alpha alpha.c  && yes | gdb /tmp/alpha -ex 'b breakpoint' -ex 'run' -ex 'n' \
    -ex 'p /x *(unsigned int*)&x@4' \
    -ex 'p /x *(unsigned short*)&x@8' \
    -ex 'p /x *(unsigned char*)&x@16' \
    -ex 'quit'
*/

static __m128i blend(__m128i dst, __m128i src);
void alpha_blend(unsigned char *dst, unsigned char *src, size_t size);

void preprocess(unsigned char *data, int w, int h) {
    for (int i = 0; i < (w * h * 4); i += 4) {
        unsigned char r = data[i + 0];
        unsigned char g = data[i + 1];
        unsigned char b = data[i + 2];
        data[i + 0] = b;
        data[i + 1] = g;
        data[i + 2] = r;
        data[i + 3] = 0;
    }
}

void preprocess_multiplied(unsigned char *data, int w, int h) {
    for (int i = 0; i < (w * h * 4); i += 4) {
        unsigned char r = data[i + 0];
        unsigned char g = data[i + 1];
        unsigned char b = data[i + 2];
        unsigned char a = data[i + 3];
        data[i + 0] = (b * a) / 0xff;
        data[i + 1] = (g * a) / 0xff;
        data[i + 2] = (r * a) / 0xff;
        data[i + 3] = a;
    }
}

void unprocess(unsigned char *data, int w, int h) {
    for (int i = 0; i < (w * h * 4); i += 4) {
        unsigned char r = data[i + 2];
        unsigned char g = data[i + 1];
        unsigned char b = data[i + 0];
        data[i + 0] = r;
        data[i + 1] = g;
        data[i + 2] = b;
        data[i + 3] = 0xff;
    }
}

void print128(__m128i var) {
    uint32_t *data = (uint32_t *)&var;
    printf("%08lx %08lx %08lx %08lx", data[0], data[1], data[2], data[3]);
}

#if 1
int main(int argc, char const *argv[]) {
    int sx, sy, _;
    printf("loading src\n");
    unsigned char *src = stbi_load("./src.png", &sx, &sy, &_, 4);

    int dx, dy;
    printf("loading dst\n");
    unsigned char *dst = stbi_load("./dst.png", &dx, &dy, &_, 4);

    assert(sx == dx && sy == dy);

    printf("preprocessing\n");
    preprocess_multiplied(src, sx, sy);
    preprocess(dst, dx, dy);

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC_RAW, &start);

    // TODO: indivisible by 4?
    size_t size = (dx * dy) / 4;  // in 128
    alpha_blend(dst, src, size);

    clock_gettime(CLOCK_MONOTONIC_RAW, &end);
    uint64_t delta_us = (end.tv_sec - start.tv_sec) * 1000000 + (end.tv_nsec - start.tv_nsec) / 1000;

    unprocess(dst, dx, dy);
    printf("took %fs\n", (float)delta_us / 1000000.0);
    stbi_write_bmp("outs.bmp", dx, dy, 4, dst);
}
#else

int main(int argc, char const *argv[]) {
    const __m128i src = _mm_setr_epi32(0x84167529, 0xab7848cd, 0xccd29459, 0xde498442);
    const __m128i dst = _mm_setr_epi32(0x00FFFFFF, 0x00FFFFFF, 0x00FFFFFF, 0x00FFFFFF);
    __m128i x = blend(dst, src);
    print128(x);
}

#endif

#endif

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

static __m128i blend(__m128i dst, __m128i src) {
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
    // a = _mm_shuffle_epi8(a, _mm_set_epi8(0, 1, 1, 1, 4, 1, 1, 1, 8, 1, 1, 1, 12, 1, 1, 1));
    a = _mm_shuffle_epi8(a, _mm_set_epi8(1, 8, 1, 8, 1, 12, 1, 12, 1, 4, 1, 4, 1, 0, 1, 0));
#else
    a = _mm_shufflehi_epi16(a, _MM_SHUFFLE(0, 0, 2, 2));
    a = _mm_shufflelo_epi16(a, _MM_SHUFFLE(2, 2, 0, 0));
#endif
    a = _mm_subs_epu8(asub, a);  // a = 0xff - a

    // RB * (0xff - alpha) / 0xff
    __m128i rb = _mm_and_si128(dst, rbmask);
    rb = _mm_mullo_epi16(rb, a);
    rb = _mm_srli_epi16(rb, 8);      // RB = RB >> 8
    rb = _mm_adds_epi16(rb, rbadd);  // RB = RB + 1
    // add:
    rb = _mm_adds_epi16(rb, _mm_and_si128(src, rbmask));  // RB += RB(src)
    rb = clip_u8(rb);

    // G * (1 - alpha)
    __m128i g = _mm_and_si128(dst, gmask);
    g = _mm_srli_epi16(g, 8);  // (trim blue portion)
    g = _mm_mullo_epi16(g, a);
    g = _mm_srli_epi16(g, 8);     // G = G >> 8
    g = _mm_adds_epi16(g, gadd);  // G = G + 1
    // add:
    __m128i src_g = _mm_srli_epi16(_mm_and_si128(src, gmask), 8);
    g = _mm_adds_epi16(g, src_g);
    g = clip_u8(g);
    // shift
    g = _mm_slli_epi16(g, 8);

    // __m128i new_dst = _mm_or_si128(rb, g);
    // new_dst = _mm

    return _mm_or_si128(rb, g);
}

void alpha_blend(unsigned char *dst, unsigned char *src, size_t size) {
    __m128i *dst128 = (__m128i *)dst;
    __m128i *src128 = (__m128i *)src;
    for (size_t i = 0; i < size; i++) {
        dst128[i] = blend(dst128[i], src128[i]);
    }
}